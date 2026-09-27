"""Exercise the real SDK serialization and retry behavior without network access."""
import json

import httpx
import pytest
from google import genai
from google.genai import types

from prb_ai.errors import Code, ComposeError
from prb_ai.contracts import TEXT_FIELD_CHOICES
from prb_ai.gemini import GeminiProvider, failure_reason, proposal_schema
from prb_ai.service import CompositionService, ProviderFailure, Usage


@pytest.fixture
def sdk(provider):
    calls = []
    reply = {
        "candidates": [{"finishReason": "STOP", "content": {
            "role": "model", "parts": [{"text": provider.output}]}}],
        "usageMetadata": {"promptTokenCount": 100, "candidatesTokenCount": 80,
                          "thoughtsTokenCount": 20, "totalTokenCount": 200},
    }
    def transport(request):
        calls.append(request)
        if request.url.path.endswith(':countTokens'):
            return httpx.Response(200, json={"totalTokens": 100})
        return httpx.Response(200, json=reply)
    with httpx.Client(transport=httpx.MockTransport(transport)) as http:
        with genai.Client(api_key="offline-test-key", vertexai=False,
                          http_options=types.HttpOptions(httpx_client=http)) as client:
            yield GeminiProvider(client), calls, reply, http


def test_provider_schema_resolves_references_and_preserves_nullable_enums():
    schema = proposal_schema()
    serialized = json.dumps(schema)
    assert '$ref' not in serialized
    assert '$defs' not in serialized
    assert 'anyOf' not in serialized
    assert schema['additionalProperties'] is False
    metric = schema['properties']['metricChanges']['items']['properties']
    assert metric['operation']['enum'] == ['add', 'update', 'remove']
    values = metric['values']
    assert values['type'] == ['object', 'null']
    comparison = values['properties']['comparison']
    assert comparison['type'] == ['string', 'null']
    assert 'lessThanOrEqual' in comparison['enum']
    assert None in comparison['enum']


def test_complete_count_matches_generation(sdk, request_model, policy):
    adapter, calls, _, _ = sdk
    assert adapter.count_input_tokens(request_model, policy) == 100
    result = adapter.generate(request_model, policy)
    assert result.usage == Usage(100, 100)
    counted = json.loads(calls[0].content)
    generated = json.loads(calls[1].content)
    assert set(counted) == {"generateContentRequest"}
    full = counted['generateContentRequest']
    assert full.pop('model') == 'models/fake'
    assert full == generated
    assert generated['generationConfig']['maxOutputTokens'] == 2000
    assert 'tools' not in generated
    instructions = generated['systemInstruction']['parts'][0]['text']
    assert json.dumps(TEXT_FIELD_CHOICES) in instructions
    assert 'clearAsk findings only for supportRequest' in instructions
    assert request_model.request_id not in calls[1].content.decode()
    assert calls[0].extensions['timeout']['read'] == 3
    assert calls[1].extensions['timeout']['read'] == 18


@pytest.mark.parametrize('status,code', [(429, Code.RATE_LIMITED), (503, Code.UNAVAILABLE), (504, Code.TIMEOUT)])
def test_sdk_does_not_retry(sdk, request_model, policy, status, code, capsys):
    adapter, calls, _, http = sdk
    def fail(request):
        calls.append(request)
        return httpx.Response(status, json={'error': {'code': status, 'message': 'sensitive text'}})
    http._transport = httpx.MockTransport(fail)
    with pytest.raises(ProviderFailure) as caught:
        adapter.generate(request_model, policy)
    assert caught.value.code == code
    assert 'sensitive' not in str(caught.value)
    assert caught.value.usage is None
    assert len(calls) == 1
    audit = json.loads(capsys.readouterr().out)
    assert audit == {'event': 'ai_provider_failure', 'operation': 'generate',
                     'kind': 'api', 'httpStatus': status, 'reason': 'unknown'}


@pytest.mark.parametrize('message,reason', [
    ('Response schema has too many states: private content', 'schema_complexity'),
    ('Invalid schema: private content', 'schema'),
    ('API key not valid: private key', 'credential'),
    ('Private unknown error', 'unknown'),
    (None, 'unknown'),
])
def test_provider_reason_never_returns_external_text(message, reason):
    assert failure_reason(message) == reason


@pytest.mark.parametrize('reason', ['MAX_TOKENS', 'SAFETY', 'RECITATION'])
def test_rejected_output_retains_known_usage(sdk, request_model, policy, reason, capsys):
    adapter, _, reply, _ = sdk
    reply['candidates'][0]['finishReason'] = reason
    with pytest.raises(ProviderFailure) as caught:
        adapter.generate(request_model, policy)
    assert caught.value.usage == Usage(100, 100)
    audit = json.loads(capsys.readouterr().out)
    assert audit['reason'] == ('truncated' if reason == 'MAX_TOKENS' else 'finish')


@pytest.mark.parametrize('metadata', [None, {}, {'promptTokenCount': 100, 'totalTokenCount': 100},
    {'promptTokenCount': 100, 'candidatesTokenCount': 80, 'totalTokenCount': 200}])
def test_incomplete_usage_stays_unknown(sdk, request_model, policy, metadata):
    adapter, _, reply, _ = sdk
    reply['usageMetadata'] = metadata
    assert adapter.generate(request_model, policy).usage is None


def test_service_validates_and_replays_sdk_result(sdk, request_model, policy, ledger, now):
    adapter, calls, _, _ = sdk
    service = CompositionService(ledger, adapter, policy, lambda: now, enabled=True)
    result = service.compose('test-user', request_model)
    assert service.compose('test-user', request_model) == result
    assert len(calls) == 2


def test_invalid_json_is_charged(sdk, request_model, policy, ledger, now):
    adapter, calls, reply, _ = sdk
    reply['candidates'][0]['content']['parts'] = [{'text': '{invalid'}]
    service = CompositionService(ledger, adapter, policy, lambda: now, enabled=True)
    with pytest.raises(ComposeError) as caught:
        service.compose('test-user', request_model)
    assert caught.value.code == Code.INVALID_OUTPUT
    assert len(calls) == 2


def test_timeout_is_unknown_without_retry(sdk, request_model, policy):
    adapter, calls, _, http = sdk
    def timeout(request):
        calls.append(request)
        raise httpx.ReadTimeout('sensitive request', request=request)
    http._transport = httpx.MockTransport(timeout)
    with pytest.raises(ProviderFailure) as caught:
        adapter.generate(request_model, policy)
    assert caught.value.code == Code.TIMEOUT
    assert caught.value.usage is None
    assert len(calls) == 1


@pytest.mark.parametrize('parts', [[], [{'functionCall': {'name': 'save', 'args': {}}}],
    [{'text': 'internal', 'thought': True}], [{'text': ''}]])
def test_non_proposal_parts_are_rejected(sdk, request_model, policy, parts):
    adapter, _, reply, _ = sdk
    reply['candidates'][0]['content']['parts'] = parts
    with pytest.raises(ProviderFailure) as caught:
        adapter.generate(request_model, policy)
    assert caught.value.code == Code.INVALID_OUTPUT


def test_blocked_prompt_is_rejected(sdk, request_model, policy):
    adapter, _, reply, _ = sdk
    reply['promptFeedback'] = {'blockReason': 'SAFETY'}
    reply['candidates'] = []
    with pytest.raises(ProviderFailure) as caught:
        adapter.generate(request_model, policy)
    assert caught.value.code == Code.INVALID_OUTPUT
