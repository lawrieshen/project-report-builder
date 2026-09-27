from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Event

import pytest

from prb_ai.budget import UsageRepository
from prb_ai.contracts import request_hash
from prb_ai.errors import Code, ComposeError
from prb_ai.service import CompositionService, ProviderFailure, Usage


def test_success_replays_durable_response(service, provider, ledger, request_model):
    first = service.compose("alice", request_model)
    assert service.compose("alice", request_model) == first
    assert provider.calls == 1
    entry = ledger.find("alice", request_model.request_id, request_hash(request_model))
    assert entry.state == "COMPLETED"
    assert entry.charged_micros == 300


def test_disabled_and_failed_accounting_never_generate(ledger, provider, policy, now, store, request_model):
    service = CompositionService(ledger, provider, policy, lambda: now)
    with pytest.raises(ComposeError, match=Code.DISABLED):
        service.compose("alice", request_model)
    assert store.rows == {}
    service.enabled = True
    store.unavailable = True
    with pytest.raises(OSError):
        service.compose("alice", request_model)
    assert provider.calls == 0


@pytest.mark.parametrize("tokens", [8_001, -1, True])
def test_complete_prompt_bounds_prevent_generation(service, provider, ledger, request_model, tokens):
    provider.tokens = tokens
    with pytest.raises(ComposeError, match=Code.INVALID_INPUT):
        service.compose("alice", request_model)
    assert provider.calls == 0
    assert ledger.find("alice", request_model.request_id, request_hash(request_model)).charged_micros == 0


@pytest.mark.parametrize("output", ['{"goalCompleted":true}', 'null', '{} {}', 'x' * 24_001])
def test_invalid_output_charges_known_usage_without_retry(service, provider, ledger, request_model, output):
    provider.output = output
    for _ in range(2):
        with pytest.raises(ComposeError, match=Code.INVALID_OUTPUT):
            service.compose("alice", request_model)
    assert provider.calls == 1
    assert ledger.find("alice", request_model.request_id, request_hash(request_model)).charged_micros == 300


def test_timeout_retains_full_reservation(service, provider, ledger, policy, request_model):
    provider.error = ProviderFailure(Code.TIMEOUT)
    for _ in range(2):
        with pytest.raises(ComposeError, match=Code.TIMEOUT):
            service.compose("alice", request_model)
    assert provider.calls == 1
    entry = ledger.find("alice", request_model.request_id, request_hash(request_model))
    assert entry.state == "OUTCOME_UNKNOWN"
    assert entry.charged_micros == policy.reservation_micros


@pytest.mark.parametrize("usage", [None, Usage(100, 2_001), Usage(True, 100)])
def test_unknown_usage_never_refunds(service, provider, ledger, policy, request_model, usage):
    provider.usage = usage
    with pytest.raises(ComposeError, match=Code.INVALID_OUTPUT):
        service.compose("alice", request_model)
    entry = ledger.find("alice", request_model.request_id, request_hash(request_model))
    assert entry.state == "OUTCOME_UNKNOWN"
    assert entry.charged_micros == policy.reservation_micros


def test_failed_settlement_cannot_redispatch_after_restart(service, provider, store, ledger, policy, now, request_model):
    provider.after_generation = lambda: setattr(store, "unavailable", True)
    with pytest.raises(OSError):
        service.compose("alice", request_model)
    store.unavailable = False
    with pytest.raises(ComposeError, match=Code.PENDING):
        service.compose("alice", request_model)
    restarted = CompositionService(UsageRepository(store), provider, policy, lambda: now + timedelta(seconds=61), enabled=True)
    with pytest.raises(ComposeError, match=Code.TIMEOUT):
        restarted.compose("alice", request_model)
    assert provider.calls == 1


def test_lost_settlement_acknowledgement_replays_result(service, provider, store, ledger, request_model):
    provider.after_generation = lambda: setattr(store, "lose_acknowledgement", True)
    with pytest.raises(OSError):
        service.compose("alice", request_model)
    assert service.compose("alice", request_model).request_id == request_model.request_id
    assert provider.calls == 1
    assert ledger.find("alice", request_model.request_id, request_hash(request_model)).charged_micros == 300


def test_transport_retry_during_generation_is_pending(service, provider, request_model):
    started, finish = Event(), Event()

    def hold_response():
        started.set()
        assert finish.wait(timeout=5)

    provider.after_generation = hold_response
    with ThreadPoolExecutor(max_workers=1) as executor:
        future = executor.submit(service.compose, "alice", request_model)
        try:
            assert started.wait(timeout=5)
            with pytest.raises(ComposeError, match=Code.PENDING):
                service.compose("alice", request_model)
        finally:
            finish.set()
        assert future.result(timeout=5).request_id == request_model.request_id
    assert provider.calls == 1
