"""Coordinate one provider generation with durable cost and result accounting."""

from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime
from typing import Protocol
from time import monotonic

from . import audit

from .budget import BudgetPolicy, Entry, State, UsageRepository
from .contracts import MAX_PROPOSAL_BYTES, Proposal, Request, Response, parse_json, request_hash
from .errors import Code, ComposeError


@dataclass(frozen=True)
class Usage:
    input_tokens: int
    output_tokens: int


@dataclass(frozen=True)
class Generation:
    proposal_json: str
    usage: Usage | None


class ProviderFailure(Exception):
    def __init__(self, code: Code, usage: Usage | None = None):
        super().__init__(code.value)
        self.code = code
        self.usage = usage


class CompositionProvider(Protocol):
    def count_input_tokens(self, request: Request, policy: BudgetPolicy) -> int:
        """Count all prompt components without issuing a billable generation."""
        ...

    def generate(self, request: Request, policy: BudgetPolicy) -> Generation:
        """Generate once without automatic retries; include reasoning in billable output usage."""
        ...


@dataclass(frozen=True)
class Outcome:
    state: State
    cost: int
    proposal: Proposal | None = None
    error: Code | None = None
    usage: Usage | None = None


class CompositionService:
    def __init__(self, usage: UsageRepository, provider: CompositionProvider, policy: BudgetPolicy,
                 clock: Callable[[], datetime], *, enabled: bool = False):
        self.usage = usage
        self.provider = provider
        self.policy = policy
        self.clock = clock
        self.enabled = enabled

    def compose(self, subject: str, request: Request) -> Response:
        if not self.enabled:
            raise ComposeError(Code.DISABLED)
        # Keep one immutable-in-practice snapshot even if the caller later edits its lists.
        request = request.model_copy(deep=True)
        entry = self.usage.reserve(subject, request.request_id, request_hash(request), self.policy, self.clock())
        if entry.state != "RESERVED":
            return self._replay(entry)
        if entry.policy != self.policy:
            raise ComposeError(Code.UNAVAILABLE)
        if not self.usage.claim(entry, self.clock()):
            return self._replay(self.usage.find(subject, request.request_id, entry.hash))
        started = monotonic()
        outcome = self._generate(request)
        response = Response.for_request(request, outcome.proposal, entry.remaining_daily_requests) if outcome.proposal else None
        # Do not catch settlement errors as provider failures: a lost acknowledgement must not refund usage.
        settled = self.usage.settle(entry, outcome.state, outcome.cost, response, outcome.error, self.clock())
        audit.generation(request.request_id, self.policy.model, settled.state, settled.charged_micros,
                         int((monotonic() - started) * 1000),
                         outcome.usage.input_tokens if outcome.usage else None,
                         outcome.usage.output_tokens if outcome.usage else None)
        return self._replay(settled)

    def _replay(self, entry: Entry) -> Response:
        if entry.state == "COMPLETED":
            return self.usage.result(entry, self.clock())
        if entry.state in {"FAILED_KNOWN", "OUTCOME_UNKNOWN"}:
            raise ComposeError(entry.error or Code.UNAVAILABLE)
        if int(self.clock().timestamp()) >= entry.lease_until:
            settled = self.usage.settle(entry, "OUTCOME_UNKNOWN", entry.reserved_micros, None, Code.TIMEOUT, self.clock())
            return self._replay(settled)
        raise ComposeError(Code.PENDING)

    def _generate(self, request: Request) -> Outcome:
        try:
            tokens = self.provider.count_input_tokens(request, self.policy)
            if type(tokens) is not int or not 0 <= tokens <= self.policy.max_input_tokens:
                return Outcome("FAILED_KNOWN", 0, error=Code.INVALID_INPUT)
        except Exception:
            # No billable generation has been attempted yet.
            return Outcome("FAILED_KNOWN", 0, error=Code.UNAVAILABLE)
        try:
            generation = self.provider.generate(request, self.policy)
        except ProviderFailure as error:
            cost = self._known_cost(error.usage)
            if cost is None:
                return self._unknown(error.code)
            return Outcome("FAILED_KNOWN", cost, error=error.code, usage=error.usage)
        except Exception:
            return self._unknown(Code.UNAVAILABLE)
        if not isinstance(generation, Generation):
            return self._unknown(Code.INVALID_OUTPUT)
        cost = self._known_cost(generation.usage)
        if cost is None:
            return self._unknown(Code.INVALID_OUTPUT)
        try:
            if len(generation.proposal_json.encode("utf-8")) > MAX_PROPOSAL_BYTES:
                audit.output_rejected('size')
                return Outcome("FAILED_KNOWN", cost, error=Code.INVALID_OUTPUT, usage=generation.usage)
            proposal = parse_json(Proposal, generation.proposal_json)
        except (ValueError, TypeError, AttributeError, RecursionError):
            audit.output_rejected('schema')
            return Outcome("FAILED_KNOWN", cost, error=Code.INVALID_OUTPUT, usage=generation.usage)
        try:
            proposal.validate_against(request)
            return Outcome("COMPLETED", cost, proposal, usage=generation.usage)
        except (ValueError, TypeError, AttributeError, RecursionError):
            audit.output_rejected('business')
            return Outcome("FAILED_KNOWN", cost, error=Code.INVALID_OUTPUT, usage=generation.usage)

    def _known_cost(self, usage: Usage | None) -> int | None:
        if not isinstance(usage, Usage):
            return None
        try:
            return self.policy.cost(usage.input_tokens, usage.output_tokens)
        except ValueError:
            return None

    def _unknown(self, code: Code) -> Outcome:
        return Outcome("OUTCOME_UNKNOWN", self.policy.reservation_micros, error=code)
