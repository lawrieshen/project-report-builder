"""Validate the shared Swift wire contract; never accept storage metadata as AI context."""

import hashlib
import json
from datetime import date
from typing import Annotated, Literal, Self, get_args

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, StringConstraints, model_validator
from pydantic.alias_generators import to_camel

MAX_REQUEST_BYTES = 64_000
MAX_PROPOSAL_BYTES = 24_000
MAX_DAILY_REQUESTS = 100


def utf16_bound(limit: int) -> AfterValidator:
    """Match the existing Java report field limits, including emoji and other supplementary characters."""
    def validate(value: str) -> str:
        if len(value.encode("utf-16-le")) // 2 > limit:
            raise ValueError("Text exceeds the field limit")
        return value

    return AfterValidator(validate)


Identifier = Annotated[str, StringConstraints(pattern=r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"), AfterValidator(str.lower)]
Name = Annotated[str, Field(max_length=200), utf16_bound(200)]
NumericText = Annotated[str, Field(max_length=100), utf16_bound(100)]
UnitText = Annotated[str, Field(max_length=50), utf16_bound(50)]
Explanation = Annotated[str, Field(max_length=1_000), utf16_bound(1_000)]
Comparison = Literal["lessThan", "lessThanOrEqual", "greaterThan", "greaterThanOrEqual", "equal"]
Severity = Literal["p0", "p1", "p2", "p3", "info"]
ProjectSize = Literal["small", "medium", "large"]
Health = Literal["green", "amber", "red"]
SummaryType = Literal["update", "blocker", "ask"]
Section = Literal["summary", "health", "milestone", "accountability", "metrics"]
Criterion = Literal["audienceFit", "languageFit", "factualAccuracy", "clearAsk", "clearBlocker"]
TextField = Literal["codeName", "lineOfBusiness", "projectSize", "ragStatus", "milestonePhase", "milestoneDeadline",
                    "summaryType", "summaryMessage", "leadEPMName", "projectDRIName"]


def valid_date(value: str) -> str:
    date.fromisoformat(value)
    return value


Day = Annotated[str, StringConstraints(pattern=r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"), AfterValidator(valid_date)]


class Model(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, frozen=True, allow_inf_nan=False,
                              alias_generator=to_camel, populate_by_name=True)


class Goal(Model):
    id: Identifier
    revision: int = Field(gt=0)
    criterion_policy_version: int = Field(ge=1, le=1)
    audience: Literal["leadership", "engineering", "stakeholders"]
    purpose: Literal["statusUpdate", "escalation", "supportRequest"]
    language: Literal["english", "traditionalChinese", "simplifiedChinese"]
    required_sections: list[Section] = Field(max_length=5)

    @model_validator(mode="after")
    def unique_sections(self) -> Self:
        if len(set(self.required_sections)) != len(self.required_sections):
            raise ValueError("Duplicate required sections")
        return self


class MetricDraft(Model):
    id: Identifier
    name: Name
    current_value_text: NumericText
    has_target: bool
    target_value_text: NumericText
    comparison: Comparison
    unit: UnitText
    severity: Severity | None = None


class Draft(Model):
    code_name: Name
    line_of_business: Name
    project_size: ProjectSize | None = None
    rag_status: Health | None = None
    milestone_phase: Name
    milestone_deadline: Day | None = None
    summary_type: SummaryType
    summary_message: Annotated[str, Field(max_length=20_000), utf16_bound(20_000)]
    lead_epm_name: Name = Field(alias="leadEPMName")
    project_dri_name: Name = Field(alias="projectDRIName")
    metrics: list[MetricDraft] = Field(max_length=100)

    @model_validator(mode="after")
    def unique_metrics(self) -> Self:
        if len({metric.id for metric in self.metrics}) != len(self.metrics):
            raise ValueError("Duplicate metric IDs")
        return self


class Message(Model):
    role: Literal["user", "assistant"]
    text: Annotated[str, Field(min_length=1, max_length=8_000), utf16_bound(8_000)]

    @model_validator(mode="after")
    def meaningful_text(self) -> Self:
        if not self.text.strip():
            raise ValueError("Empty message")
        return self


class Request(Model):
    request_id: Identifier = Field(alias="requestID")
    base_draft_version: Identifier
    candidate_version: Identifier
    goal: Goal
    draft: Draft
    messages: list[Message] = Field(min_length=1, max_length=12)

    @model_validator(mode="after")
    def last_message_is_user(self) -> Self:
        if self.messages[-1].role != "user":
            raise ValueError("Last message must be from user")
        return self


TEXT_FIELD_CHOICES = {
    "lineOfBusiness": ("iPhone", "Mac", "iPad", "Wearables, Home and Accessories", "Services"),
    "projectSize": get_args(ProjectSize),
    "ragStatus": ("green", "amber", "red"),
    "milestonePhase": ("Prototype", "EVT", "DVT", "PVT", "Mass Production"),
    "summaryType": ("update", "blocker", "ask"),
}


class TextChange(Model):
    field: TextField
    operation: Literal["set", "clear"]
    value: str | None = None

    @model_validator(mode="after")
    def valid_change(self) -> Self:
        if self.operation == "clear":
            if self.value is not None or self.field == "summaryType":
                raise ValueError("Invalid clear operation")
            return self
        limit = 20_000 if self.field == "summaryMessage" else 200
        if self.value is None or not self.value.strip() or len(self.value.encode("utf-16-le")) // 2 > limit:
            raise ValueError("Invalid set value")
        if self.field in TEXT_FIELD_CHOICES and self.value not in TEXT_FIELD_CHOICES[self.field]:
            raise ValueError("Unsupported field value")
        if self.field == "milestoneDeadline":
            if len(self.value) != 10 or date.fromisoformat(self.value).isoformat() != self.value:
                raise ValueError("Invalid calendar date")
        return self


class MetricValues(Model):
    name: Name
    current_value: float
    target_value: float | None = None
    comparison: Comparison | None = None
    unit: UnitText | None = None
    severity: Severity | None = None

    @model_validator(mode="after")
    def valid_values(self) -> Self:
        if not self.name.strip() or (self.target_value is None) != (self.comparison is None):
            raise ValueError("Name and paired target/comparison required")
        return self


class MetricChange(Model):
    operation: Literal["add", "update", "remove"]
    id: Identifier | None = None
    values: MetricValues | None = None

    @model_validator(mode="after")
    def valid_operation(self) -> Self:
        if (self.operation == "add") != (self.id is None):
            raise ValueError("Only existing metrics carry an ID")
        if (self.operation == "remove") != (self.values is None):
            raise ValueError("Only add/update carry values")
        return self


class Finding(Model):
    criterion_id: Criterion = Field(alias="criterionID")
    explanation: Explanation = Field(min_length=1)

    @model_validator(mode="after")
    def nonblank_explanation(self) -> Self:
        if not self.explanation.strip():
            raise ValueError("An explanation is required")
        return self


class Proposal(Model):
    assistant_message: Annotated[str, Field(min_length=1, max_length=4_000), utf16_bound(4_000)]
    clarifying_questions: list[Explanation] = Field(max_length=5)
    proposed_changes: list[TextChange] = Field(max_length=len(get_args(TextField)))
    metric_changes: list[MetricChange] = Field(max_length=100)
    warnings: list[Explanation] = Field(max_length=10)
    semantic_findings: list[Finding] = Field(max_length=5)

    @model_validator(mode="after")
    def unique_changes(self) -> Self:
        if not self.assistant_message.strip():
            raise ValueError("An assistant message is required")
        if len({change.field for change in self.proposed_changes}) != len(self.proposed_changes):
            raise ValueError("Duplicate field changes")
        if len({finding.criterion_id for finding in self.semantic_findings}) != len(self.semantic_findings):
            raise ValueError("Duplicate findings")
        return self

    def validate_against(self, request: Request) -> None:
        """Reject invented metric IDs and assessments unrelated to the submitted goal."""
        if "project_size" not in request.draft.model_fields_set and any(
                change.field == "projectSize" for change in self.proposed_changes):
            raise ValueError("Client does not support project size proposals")
        available = {metric.id for metric in request.draft.metrics}
        changed: set[str] = set()
        count = len(available)
        for change in self.metric_changes:
            if change.id is not None:
                if change.id not in available or change.id in changed:
                    raise ValueError("Invalid metric reference")
                changed.add(change.id)
            if change.operation == "add":
                count += 1
            elif change.operation == "remove":
                count -= 1
        if count > 100:
            raise ValueError("Too many metrics")
        for finding in self.semantic_findings:
            if finding.criterion_id == "clearAsk" and request.goal.purpose != "supportRequest":
                raise ValueError("Ask assessment needs a support request goal")
            if finding.criterion_id == "clearBlocker" and request.goal.purpose != "escalation":
                raise ValueError("Blocker assessment needs an escalation goal")


class Response(Model):
    request_id: Identifier = Field(alias="requestID")
    base_draft_version: Identifier
    candidate_version: Identifier
    goal_id: Identifier = Field(alias="goalID")
    goal_revision: int = Field(gt=0)
    proposal: Proposal
    remaining_daily_requests: int = Field(ge=0, le=MAX_DAILY_REQUESTS)

    @classmethod
    def for_request(cls, request: Request, proposal: Proposal, remaining: int) -> Self:
        return cls(request_id=request.request_id, base_draft_version=request.base_draft_version,
                   candidate_version=request.candidate_version, goal_id=request.goal.id,
                   goal_revision=request.goal.revision, proposal=proposal, remaining_daily_requests=remaining)


def unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON property")
        result[key] = value
    return result


def reject_constant(value: str) -> None:
    raise ValueError("Nonfinite JSON number")


def parse_json[T: BaseModel](model: type[T], body: str | bytes) -> T:
    """Reject duplicate keys, trailing data, and nonfinite numbers before model validation."""
    decoded = json.loads(body, object_pairs_hook=unique_object, parse_constant=reject_constant)
    json.dumps(decoded, ensure_ascii=False, allow_nan=False).encode("utf-8")
    return model.model_validate(decoded, by_alias=True, by_name=False)


def request_hash(request: Request) -> str:
    payload = request.model_dump(mode="json", by_alias=True)
    # Preserve hashes for already-admitted requests from clients without this field.
    if "project_size" not in request.draft.model_fields_set:
        payload["draft"].pop("projectSize")
    canonical = json.dumps(payload, sort_keys=True,
                           separators=(",", ":"), ensure_ascii=False, allow_nan=False)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()
