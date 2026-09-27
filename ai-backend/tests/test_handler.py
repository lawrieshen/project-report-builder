import base64
import json
from datetime import UTC, datetime

import pytest

from prb_ai.handler import Authentication, ComposeHandler, lambda_handler


def event_for(request_model, now):
    return {"version": "2.0", "routeKey": "POST /ai/compose", "body": request_model.model_dump_json(by_alias=True),
            "requestContext": {"authorizer": {"jwt": {"claims": {
                "iss": "issuer", "client_id": "client", "sub": "alice", "token_use": "access",
                "scope": "reports/write", "exp": str(int(now.timestamp()) + 100)}}}}}


def handler(service=None):
    return ComposeHandler(Authentication("issuer", "client", "alice"), service)


def test_valid_auth_with_disabled_service(request_model, now):
    result = handler().handle(event_for(request_model, now), now)
    assert result["statusCode"] == 503
    assert json.loads(result["body"])["code"] == "AI_DISABLED"


@pytest.mark.parametrize("key,value", [("sub", "bob"), ("iss", "wrong"), ("client_id", "wrong"),
                                      ("scope", "reports/read"), ("exp", "0"), ("exp", "garbage"), ("token_use", "id")])
def test_invalid_claims_rejected_before_quota(key, value, request_model, now, service, store):
    event = event_for(request_model, now)
    event["requestContext"]["authorizer"]["jwt"]["claims"][key] = value
    assert handler(service).handle(event, now)["statusCode"] == 401
    assert store.rows == {}


def test_missing_authorizer_cannot_be_replaced_by_header(request_model, now, service, store):
    event = event_for(request_model, now)
    event["requestContext"] = None
    event["headers"] = {"Authorization": "Bearer unverified-token"}
    assert handler(service).handle(event, now)["statusCode"] == 401
    assert store.rows == {}


@pytest.mark.parametrize("encoded", [False, True])
def test_decoded_utf8_size_checked(encoded, request_model, now, service, store):
    event = event_for(request_model, now)
    body = "漢" * 22_000
    event["body"] = base64.b64encode(body.encode()).decode() if encoded else body
    event["isBase64Encoded"] = encoded
    assert handler(service).handle(event, now)["statusCode"] == 400
    assert store.rows == {}


@pytest.mark.parametrize("body", ["null", "{}", "{} {}", '{"messages":[],"messages":[]}', "[" * 2_000])
def test_malformed_body_has_no_side_effects(body, request_model, now, service, store):
    event = event_for(request_model, now)
    event["body"] = body
    assert handler(service).handle(event, now)["statusCode"] == 400
    assert store.rows == {}


def test_storage_failures_are_sanitized(request_model, now, service, store, caplog):
    store.unavailable = True
    result = handler(service).handle(event_for(request_model, now), now)
    assert result["statusCode"] == 503
    assert "Unavailable test store" not in caplog.text
    assert request_model.draft.code_name not in caplog.text


def test_success_uses_swift_wire_names(service, request_model, now):
    result = handler(service).handle(event_for(request_model, now), now)
    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert body["requestID"] == request_model.request_id
    assert "request_id" not in body
    assert body["proposal"]["proposedChanges"][0]["field"] == "summaryMessage"
    assert result["headers"]["cache-control"] == "no-store"


def test_lambda_entry_remains_off_even_with_enable_env(monkeypatch, request_model):
    for key, value in {"COGNITO_ISSUER": "issuer", "COGNITO_CLIENT_ID": "client", "APPROVED_SUBJECT": "alice", "AI_ENABLED": "true"}.items():
        monkeypatch.setenv(key, value)
    result = lambda_handler(event_for(request_model, datetime.now(UTC)), None)
    assert json.loads(result["body"])["code"] == "AI_DISABLED"
