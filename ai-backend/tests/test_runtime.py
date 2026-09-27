import json
from contextlib import ExitStack
from datetime import UTC, datetime, timedelta
from unittest.mock import Mock

import pytest

from prb_ai.errors import Code, ComposeError
from prb_ai.runtime import build_service, runtime_policy
from prb_ai.handler import Authentication, ComposeHandler
from test_handler import event_for


def settings(policy):
    return {'AI_ENABLED': 'true', 'AI_BUDGET_POLICY': policy.model_dump_json(),
            'AI_PRICE_VALID_UNTIL': (datetime.now(UTC) + timedelta(days=1)).isoformat(),
            'AWS_REGION': 'ap-southeast-2', 'AI_USAGE_TABLE': 'test-usage',
            'GEMINI_SECRET_ARN': 'test-secret'}


def test_disabled_never_constructs_clients(monkeypatch):
    create = Mock(side_effect=AssertionError('Must not load credentials'))
    monkeypatch.setattr('prb_ai.runtime.boto3.client', create)
    with ExitStack() as resources, pytest.raises(ComposeError) as error:
        build_service({}, resources)
    assert error.value.code == Code.DISABLED
    create.assert_not_called()


@pytest.mark.parametrize('key,value', [('AI_PRICE_VALID_UNTIL', '2020-01-01T00:00:00Z'),
    ('AI_PRICE_VALID_UNTIL', '2099-01-01'), ('AI_BUDGET_POLICY', '{}'),
    ('AI_BUDGET_POLICY', '{invalid')])
def test_bad_pricing_prevents_secret_access(policy, monkeypatch, key, value):
    environment = settings(policy)
    environment[key] = value
    create = Mock()
    monkeypatch.setattr('prb_ai.runtime.boto3.client', create)
    with ExitStack() as resources, pytest.raises(ComposeError):
        build_service(environment, resources)
    create.assert_not_called()


def test_monthly_limit_cannot_exceed_owner_approval(policy):
    environment = settings(policy)
    environment['AI_BUDGET_POLICY'] = policy.model_copy(update={'monthly_limit_micros': 8_000_001}).model_dump_json()
    with pytest.raises(ComposeError):
        runtime_policy(environment, datetime.now(UTC))


def test_enabled_runtime_loads_key_and_closes_clients(policy, monkeypatch):
    secrets, dynamo, google = Mock(), Mock(), Mock(vertexai=False)
    secrets.get_secret_value.return_value = {'SecretString': '{"GEMINI_API_KEY":"dummy"}'}
    aws = Mock(side_effect=[secrets, dynamo])
    make_google = Mock(return_value=google)
    monkeypatch.setattr('prb_ai.runtime.boto3.client', aws)
    monkeypatch.setattr('prb_ai.runtime.genai.Client', make_google)
    with ExitStack() as resources:
        service = build_service(settings(policy), resources)
        assert service.policy == policy
        secrets.get_secret_value.assert_called_once_with(SecretId='test-secret', VersionStage='AWSCURRENT')
        assert make_google.call_args.kwargs['api_key'] == 'dummy'
        assert service.enabled
    for client in (secrets, dynamo, google):
        client.close.assert_called_once()


@pytest.mark.parametrize('invalid', ['auth', 'body', 'route'])
def test_invalid_request_never_initializes_runtime(request_model, now, invalid):
    event = event_for(request_model, now)
    if invalid == 'auth':
        event['requestContext'] = {}
    elif invalid == 'body':
        event['body'] = '{}'
    else:
        event['routeKey'] = 'GET /ai/compose'
    factory = Mock()
    handler = ComposeHandler(Authentication('issuer', 'client', 'alice'), service_factory=factory)
    assert handler.handle(event, now)['statusCode'] in (400, 401, 404)
    factory.assert_not_called()
