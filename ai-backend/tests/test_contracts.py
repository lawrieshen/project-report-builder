import json

import pytest
from pydantic import ValidationError

from conftest import FIXTURES
from prb_ai.contracts import MetricValues, Proposal, Request, Response, TextChange, parse_json, request_hash


def test_shared_swift_fixtures_round_trip(request_model):
    response = parse_json(Response, (FIXTURES / "response.json").read_bytes())
    response.proposal.validate_against(request_model)
    assert response == Response.for_request(request_model, response.proposal, 19)
    assert parse_json(Request, request_model.model_dump_json(by_alias=True)) == request_model


def test_follow_up_preserves_numeric_text_and_enums():
    request = parse_json(Request, (FIXTURES / "follow-up-request.json").read_bytes())
    assert request.draft.metrics[0].current_value_text == "2.50"
    assert request.draft.metrics[0].comparison == "lessThanOrEqual"
    assert request.draft.metrics[0].severity == "p1"
    assert request.draft.milestone_deadline == "2026-10-01"
    assert len(request.messages) == 3


@pytest.mark.parametrize("field", ["assets", "ownerID", "status", "revision", "localReference"])
def test_no_storage_metadata(field, request_model):
    body = request_model.model_dump(mode="json", by_alias=True)
    body["draft"][field] = "injected"
    with pytest.raises(ValidationError):
        parse_json(Request, json.dumps(body))


@pytest.mark.parametrize("field,operation,value", [
    ("ownerID", "set", "other"), ("summaryMessage", "clear", "not null"), ("summaryMessage", "set", None),
    ("summaryType", "clear", None), ("milestoneDeadline", "set", "2026-02-30"),
    ("milestoneDeadline", "set", "20260927"), ("ragStatus", "set", "blue"), ("summaryMessage", "set", " "),
])
def test_bad_changes(field, operation, value):
    with pytest.raises(ValidationError):
        TextChange(field=field, operation=operation, value=value)


@pytest.mark.parametrize("bad", [True, "1", 1.0, 2])
def test_goal_policy_is_strict(request_model, bad):
    body = request_model.model_dump(mode="json", by_alias=True)
    body["goal"]["criterionPolicyVersion"] = bad
    with pytest.raises(ValidationError):
        parse_json(Request, json.dumps(body))


@pytest.mark.parametrize("role", ["system", "tool", "developer"])
def test_client_cannot_supply_system_instructions(request_model, role):
    body = request_model.model_dump(mode="json", by_alias=True)
    body["messages"][0]["role"] = role
    with pytest.raises(ValidationError):
        parse_json(Request, json.dumps(body))


@pytest.mark.parametrize("value", [float("inf"), float("nan"), True, "2.5"])
def test_output_numbers_must_be_finite_numbers(value):
    with pytest.raises(ValidationError):
        MetricValues(name="Bugs", current_value=value)


def test_required_primitive_is_not_defaulted():
    body = json.loads((FIXTURES / "follow-up-request.json").read_text())
    del body["draft"]["metrics"][0]["hasTarget"]
    with pytest.raises(ValidationError):
        parse_json(Request, json.dumps(body))
    with pytest.raises(ValidationError):
        MetricValues(name="Bugs")


@pytest.mark.parametrize("body", ['{} {}', '{"goal":1,"goal":2}', '{"x":NaN}', '{"x":1e999}', '{"x":"\\ud800"}'])
def test_json_ambiguity_rejected(body):
    with pytest.raises(ValueError):
        parse_json(Request, body)


def test_hash_ignores_key_order_uuid_case_and_optional_null(request_model):
    body = request_model.model_dump(mode="json", by_alias=True)
    body["requestID"] = body["requestID"].upper()
    del body["draft"]["ragStatus"]
    assert request_hash(request_model) == request_hash(parse_json(Request, json.dumps(body, sort_keys=True)))
    body["goal"]["revision"] += 1
    assert request_hash(request_model) != request_hash(parse_json(Request, json.dumps(body)))


def test_duplicate_fields_and_unknown_metric_references(request_model):
    body = json.loads((FIXTURES / "response.json").read_text())["proposal"]
    body["proposedChanges"] *= 2
    with pytest.raises(ValidationError):
        parse_json(Proposal, json.dumps(body))
    body["proposedChanges"] = []
    body["metricChanges"] = [{"operation": "remove", "id": request_model.request_id}]
    proposal = parse_json(Proposal, json.dumps(body))
    with pytest.raises(ValueError):
        proposal.validate_against(request_model)


def test_unknown_provider_claims_cannot_complete_goal():
    with pytest.raises(ValidationError):
        parse_json(Proposal, '{"goalCompleted":true}')


def test_emoji_counts_match_existing_java_storage_limits(request_model):
    body = request_model.model_dump(mode="json", by_alias=True)
    body["draft"]["codeName"] = "😀" * 100
    assert parse_json(Request, json.dumps(body)).draft.code_name == body["draft"]["codeName"]
    body["draft"]["codeName"] += "😀"
    with pytest.raises(ValidationError):
        parse_json(Request, json.dumps(body))
    with pytest.raises(ValidationError):
        TextChange(field="codeName", operation="set", value=body["draft"]["codeName"])
