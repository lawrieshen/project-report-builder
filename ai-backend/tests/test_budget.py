from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier
from uuid import uuid4

import pytest

from prb_ai.budget import BudgetPolicy, UsageRepository
from prb_ai.contracts import Proposal, Response
from prb_ai.errors import Code, ComposeError


def reserve(ledger, policy, now, subject="alice"):
    return ledger.reserve(subject, str(uuid4()), "hash", policy, now)


def test_approved_hundred_attempt_limit_preserves_existing_daily_count(ledger, policy, now):
    first = reserve(ledger, policy, now)
    ledger.claim(first, now)
    ledger.settle(first, 'FAILED_KNOWN', 0, None, Code.INVALID_OUTPUT, now)
    upgraded = BudgetPolicy(**{**policy.model_dump(), 'daily_limit': 100})
    second = reserve(ledger, upgraded, now)
    assert second.remaining_daily_requests == 98
    assert ledger.reserve('alice', first.request_id, 'hash', upgraded, now).remaining_daily_requests == 1
    with pytest.raises(ValueError):
        BudgetPolicy(**{**policy.model_dump(), 'daily_limit': 101})


def test_integer_money_rounds_up(policy):
    fractional = policy.model_copy(update={"input_micros_per_million": 1, "output_micros_per_million": 1})
    assert fractional.cost(1, 1) == 2
    assert fractional.cost(0, 0) == 0
    for values in [(8_001, 0), (0, 2_001), (True, 0), (-1, 0)]:
        with pytest.raises(ValueError):
            policy.cost(*values)
    with pytest.raises(ValueError):
        BudgetPolicy(**{**policy.model_dump(), "monthly_limit_micros": 11_000_000})


def test_duplicate_reserves_and_claims_once(ledger, policy, now):
    first = reserve(ledger, policy, now)
    assert first == ledger.reserve("alice", first.request_id, "hash", policy, now)
    assert ledger.claim(first, now)
    assert not ledger.claim(first, now)
    with pytest.raises(ComposeError, match=Code.MISMATCH):
        ledger.reserve("alice", first.request_id, "changed", policy, now)


def test_parallel_subjects_share_one_monthly_budget(ledger, policy, now):
    gate = Barrier(8)

    def attempt(i):
        gate.wait(timeout=5)
        try:
            reserve(ledger, policy, now, f"owner{i}")
            return True
        except ComposeError as error:
            assert error.code in {Code.BUDGET_EXHAUSTED, Code.UNAVAILABLE}
            return False

    with ThreadPoolExecutor(max_workers=8) as executor:
        assert sum(executor.map(attempt, range(8))) == 2


def test_parallel_dispatch_claims_one_winner(ledger, policy, now):
    entry = reserve(ledger, policy, now)
    with ThreadPoolExecutor(max_workers=8) as executor:
        assert sum(executor.map(lambda _: ledger.claim(entry, now), range(8))) == 1


def test_expired_lease_allows_new_id_not_replay(ledger, policy, now):
    first = reserve(ledger, policy, now)
    assert ledger.claim(first, now)
    with pytest.raises(ComposeError, match=Code.PENDING):
        reserve(ledger, policy, now)
    later = now + timedelta(seconds=61)
    second = reserve(ledger, policy, later)
    assert not ledger.claim(first, later)
    settled = ledger.settle(first, "OUTCOME_UNKNOWN", 0, None, Code.TIMEOUT, later)
    assert settled.charged_micros == first.reserved_micros
    with pytest.raises(ComposeError, match=Code.PENDING):
        reserve(ledger, policy, later)
    assert ledger.claim(second, later)


def test_known_refund_is_once_and_does_not_restore_daily_attempt(ledger, policy, now):
    first = reserve(ledger, policy, now)
    ledger.claim(first, now)
    settled = ledger.settle(first, "FAILED_KNOWN", 100, None, Code.INVALID_OUTPUT, now)
    assert settled == ledger.settle(first, "FAILED_KNOWN", 0, None, Code.INVALID_OUTPUT, now)
    second = reserve(ledger, policy, now)
    assert second.remaining_daily_requests == 0
    ledger.claim(second, now)
    ledger.settle(second, "FAILED_KNOWN", 0, None, Code.INVALID_OUTPUT, now)
    with pytest.raises(ComposeError, match=Code.DAILY_QUOTA):
        reserve(ledger, policy, now)
    assert reserve(ledger, policy, now + timedelta(seconds=20)).remaining_daily_requests == 1


def test_utc_rollover_settles_original_month(ledger, policy, now):
    entry = reserve(ledger, policy, now)
    ledger.claim(entry, now)
    ledger.settle(entry, "FAILED_KNOWN", 100, None, Code.INVALID_OUTPUT, now + timedelta(seconds=20))
    assert reserve(ledger, policy, now, "bob").month == "2026-09"
    assert reserve(ledger, policy, now + timedelta(seconds=20)).month == "2026-10"


def test_response_expiry_preserves_idempotency_record(ledger, store, policy, now, request_model):
    entry = ledger.reserve("alice", request_model.request_id, "hash", policy, now)
    ledger.claim(entry, now)
    proposal = Proposal(assistant_message="Review", clarifying_questions=[], proposed_changes=[], metric_changes=[], warnings=[], semantic_findings=[])
    response = Response.for_request(request_model, proposal, 1)
    done = ledger.settle(entry, "COMPLETED", 200, response, None, now)
    assert UsageRepository(store).result(done, now) == response
    tomorrow = now + timedelta(days=1)
    with pytest.raises(ComposeError, match=Code.EXPIRED):
        ledger.result(done, tomorrow)
    assert ledger.reserve("alice", entry.request_id, "hash", policy, tomorrow) == done
    assert not ledger.claim(done, tomorrow)
    assert all(row.expires_at is None for key, row in store.rows.items() if not key.startswith("RESULT#"))


def test_settlement_failure_retains_reservation(ledger, store, policy, now):
    entry = reserve(ledger, policy, now)
    ledger.claim(entry, now)
    store.unavailable = True
    with pytest.raises(OSError):
        ledger.settle(entry, "FAILED_KNOWN", 0, None, Code.INVALID_OUTPUT, now)
    store.unavailable = False
    retained = ledger.find("alice", entry.request_id, "hash")
    assert retained.state == "RUNNING"
    assert retained.charged_micros == entry.reserved_micros
    assert not ledger.claim(retained, now + timedelta(seconds=61))
