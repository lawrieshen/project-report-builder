"""Reserve costs conservatively; retain charges when provider execution is uncertain."""

from datetime import UTC, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from . import audit
from .contracts import Response
from .errors import Code, ComposeError
from .storage import Row, UsageStore, Write


class LedgerModel(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid", frozen=True)


class BudgetPolicy(LedgerModel):
    model: str = Field(min_length=1)
    price_version: str = Field(min_length=1)
    input_micros_per_million: int = Field(gt=0)
    output_micros_per_million: int = Field(gt=0)
    monthly_limit_micros: int = Field(gt=0, le=10_000_000)
    daily_limit: int = Field(gt=0, le=20)
    max_input_tokens: int = Field(gt=0, le=8_000)
    max_output_tokens: int = Field(gt=0, le=2_000)

    @property
    def reservation_micros(self) -> int:
        return self.cost(self.max_input_tokens, self.max_output_tokens)

    def cost(self, input_tokens: int, output_tokens: int) -> int:
        """Include reasoning in output tokens and round each component up to micro-USD."""
        if (type(input_tokens) is not int or type(output_tokens) is not int
                or not 0 <= input_tokens <= self.max_input_tokens or not 0 <= output_tokens <= self.max_output_tokens):
            raise ValueError("Usage exceeds verified bounds")
        return ((input_tokens * self.input_micros_per_million + 999_999) // 1_000_000
                + (output_tokens * self.output_micros_per_million + 999_999) // 1_000_000)


State = Literal["RESERVED", "RUNNING", "COMPLETED", "FAILED_KNOWN", "OUTCOME_UNKNOWN"]


class Entry(LedgerModel):
    subject: str
    request_id: str
    hash: str
    month: str
    day: str
    policy: BudgetPolicy
    reserved_micros: int = Field(ge=0)
    charged_micros: int = Field(ge=0)
    remaining_daily_requests: int = Field(ge=0, le=20)
    lease_until: int
    result_until: int = 0
    state: State = "RESERVED"
    error: Code | None = None


class Counter(LedgerModel):
    value: int = Field(ge=0)


class Lease(LedgerModel):
    request_id: str
    until: int


class UsageRepository:
    max_attempts = 5
    lease_seconds = 60
    result_seconds = 86_400

    def __init__(self, store: UsageStore):
        self.store = store

    def reserve(self, subject: str, request_id: str, request_hash: str, policy: BudgetPolicy, now: datetime) -> Entry:
        """Atomically reserve monthly money, a daily attempt, and the user's in-flight lease."""
        if not subject.strip() or not request_id or not request_hash:
            raise ComposeError(Code.INVALID_INPUT)
        if now.tzinfo is None:
            raise ValueError("An aware clock is required")
        utc = now.astimezone(UTC)
        month, day = utc.strftime("%Y-%m"), utc.date().isoformat()
        request_key = f"REQUEST#{subject}#{request_id}"
        month_key, day_key, lease_key = f"MONTH#{month}", f"DAY#{subject}#{day}", f"LEASE#{subject}"
        reserved = policy.reservation_micros
        for _ in range(self.max_attempts):
            request_row = self.store.read(request_key)
            if request_row is not None:
                return self._matching(request_row, request_hash)
            month_row, day_row, lease_row = self.store.read(month_key), self.store.read(day_key), self.store.read(lease_key)
            spent, daily = self._count(month_row), self._count(day_row)
            if spent + reserved > policy.monthly_limit_micros:
                raise ComposeError(Code.BUDGET_EXHAUSTED)
            if daily >= policy.daily_limit:
                raise ComposeError(Code.DAILY_QUOTA)
            if lease_row is not None and Lease.model_validate_json(lease_row.data).until > int(now.timestamp()):
                raise ComposeError(Code.PENDING)
            entry = Entry(subject=subject, request_id=request_id, hash=request_hash, month=month, day=day, policy=policy,
                          reserved_micros=reserved, charged_micros=reserved, remaining_daily_requests=policy.daily_limit - daily - 1,
                          lease_until=int(now.timestamp()) + self.lease_seconds)
            writes = [self._write(request_key, None, entry),
                      self._write(month_key, month_row, Counter(value=spent + reserved)),
                      self._write(day_key, day_row, Counter(value=daily + 1)),
                      self._write(lease_key, lease_row, Lease(request_id=request_id, until=entry.lease_until))]
            if self.store.commit(writes):
                audit.budget_usage(spent + reserved, policy.monthly_limit_micros)
                return entry
        raise ComposeError(Code.UNAVAILABLE)

    def claim(self, reserved: Entry, now: datetime) -> bool:
        """Grant one dispatch; expiration never grants another dispatch for this ID."""
        row = self._request_row(reserved.subject, reserved.request_id)
        entry = self._matching(row, reserved.hash)
        if entry.state != "RESERVED" or int(now.timestamp()) >= entry.lease_until:
            return False
        running = entry.model_copy(update={"state": "RUNNING"})
        return self.store.commit([self._write(row.key, row, running)])

    def find(self, subject: str, request_id: str, request_hash: str) -> Entry:
        return self._matching(self._request_row(subject, request_id), request_hash)

    def settle(self, dispatched: Entry, state: State, actual_micros: int, response: Response | None,
               error: Code | None, now: datetime) -> Entry:
        """Persist settlement and its retry result together; never refund uncertain usage."""
        if state not in {"COMPLETED", "FAILED_KNOWN", "OUTCOME_UNKNOWN"}:
            raise ValueError("A terminal outcome is required")
        if (state == "COMPLETED") != (response is not None) or (state == "COMPLETED") != (error is None):
            raise ValueError("Result and error must match the terminal outcome")
        for _ in range(self.max_attempts):
            row = self._request_row(dispatched.subject, dispatched.request_id)
            entry = self._matching(row, dispatched.hash)
            if entry.state not in {"RESERVED", "RUNNING"}:
                return entry
            if entry.state == "RESERVED" and state != "OUTCOME_UNKNOWN":
                raise ValueError("Dispatch must be claimed before settlement")
            charged = entry.reserved_micros if state == "OUTCOME_UNKNOWN" else actual_micros
            if type(charged) is not int or not 0 <= charged <= entry.reserved_micros:
                raise ValueError("Invalid usage charge")
            month_key = f"MONTH#{entry.month}"
            month_row = self.store.read(month_key)
            if month_row is None:
                raise ComposeError(Code.UNAVAILABLE)
            updated = self._count(month_row) - entry.reserved_micros + charged
            if updated < 0:
                raise ComposeError(Code.UNAVAILABLE)
            until = int(now.timestamp()) + self.result_seconds
            settled = entry.model_copy(update={"state": state, "charged_micros": charged, "result_until": until, "error": error})
            writes = [self._write(row.key, row, settled), self._write(month_key, month_row, Counter(value=updated))]
            if response is not None:
                writes.append(self._write(self._result_key(entry), None, response, until))
            lease_key = f"LEASE#{entry.subject}"
            lease_row = self.store.read(lease_key)
            if lease_row is not None and Lease.model_validate_json(lease_row.data).request_id == entry.request_id:
                writes.append(self._write(lease_key, lease_row, Lease(request_id=entry.request_id, until=0)))
            if self.store.commit(writes):
                audit.budget_usage(updated, entry.policy.monthly_limit_micros)
                return settled
        raise ComposeError(Code.UNAVAILABLE)

    def result(self, entry: Entry, now: datetime) -> Response:
        if entry.state != "COMPLETED":
            raise ComposeError(Code.PENDING)
        if int(now.timestamp()) >= entry.result_until:
            raise ComposeError(Code.EXPIRED)
        row = self.store.read(self._result_key(entry))
        if row is None:
            raise ComposeError(Code.UNAVAILABLE)
        if row.expires_at is None or int(now.timestamp()) >= row.expires_at:
            raise ComposeError(Code.EXPIRED)
        return Response.model_validate_json(row.data)

    def _request_row(self, subject: str, request_id: str) -> Row:
        row = self.store.read(f"REQUEST#{subject}#{request_id}")
        if row is None:
            raise ComposeError(Code.UNAVAILABLE)
        return row

    @staticmethod
    def _result_key(entry: Entry) -> str:
        return f"RESULT#{entry.subject}#{entry.request_id}"

    @staticmethod
    def _matching(row: Row, request_hash: str) -> Entry:
        entry = Entry.model_validate_json(row.data)
        if entry.hash != request_hash:
            raise ComposeError(Code.MISMATCH)
        return entry

    @staticmethod
    def _count(row: Row | None) -> int:
        return Counter.model_validate_json(row.data).value if row else 0

    @staticmethod
    def _write(key: str, previous: Row | None, value: BaseModel, expires_at: int | None = None) -> Write:
        return Write(key, previous.version if previous else 0, value.model_dump_json(by_alias=True), expires_at)
