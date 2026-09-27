# AI report composition service

This independent Python 3.12 service owns AI composition and budget accounting.
The existing Java service in `backend/` continues to own report CRUD and images.
The Swift Goal evaluator and UI state graph remain in the app.

**Foundation only: not deployed or enabled.** The Lambda entry point
`prb_ai.handler.lambda_handler` returns `AI_DISABLED` for valid authorized requests.
Setting `AI_ENABLED` cannot bypass this gate. No Gemini client or API key is loaded.
The official Google GenAI SDK adapter, verified model/pricing, deployment packaging,
CDK resources, live latency/cost checks, and app enablement remain later milestones.

## Local development

From `ai-backend/`, with Python 3.12 and uv installed:

```sh
uv sync --frozen --extra test
uv run --frozen --extra test pytest
uv build
```

`uv.lock` pins runtime and test dependencies. Tests use synthetic prices, a fake
provider, an atomic memory store, and botocore Stubber. They require no AWS profile,
secret, Google project, network calls, or paid resources. Stubbed SDK checks do not
replace a DynamoDB integration test before deployment. `uv build` produces a Python
distribution; it does not package Lambda's Linux dependencies or deploy AWS resources.

## Responsibilities

| Module | Responsibility |
| --- | --- |
| `contracts.py` | Strict Pydantic models, shared Swift wire names, field allowlists and canonical request hashes |
| `budget.py` | Integer micro-USD pricing, atomic quota reservation, one dispatch claim and idempotent settlement |
| `storage.py` | Strong DynamoDB reads and conditional transactional writes |
| `service.py` | One injectable provider invocation, proposal validation, durable result and cost accounting |
| `handler.py` | Gateway Cognito claims, approved subject, `reports/write`, input bounds and sanitized HTTP errors |

Shared request/response examples are in
[`backend/contracts/ai-compose/v1`](../backend/contracts/ai-compose/v1/README.md).
Their location preserves the existing Swift fixture paths; Python does not depend
on the Java service or Maven. Generate the provider schema from
`Proposal.model_json_schema(by_alias=True)` and enforce the field-specific validators
again after generation. JSON schema alone does not verify facts or satisfy a goal.

## Accounting rules

- All callers share the monthly `MONTH#YYYY-MM` counter. Per-user attempts use UTC
  day keys and are not refunded on failed generations.
- Reserve the maximum configured input/output cost before generation. Count the
  complete prompt before generating; the provider must enforce both token bounds
  and report all billable reasoning/output tokens. No paid tools or automatic retries.
- A conditional `RESERVED → RUNNING` transition grants exactly one dispatch. An
  expired lease allows a new request ID but never redispatch of an old request.
- Known usage refunds only the unused reservation. Unknown outcomes, missing usage,
  timeouts and failed settlement retain the conservative charge.
- Store a completed result and its settlement in the same transaction. If the
  acknowledgement is lost, the same request ID retrieves the durable result.
- Bind each ID to its validated canonical payload; different content returns
  `REQUEST_MISMATCH`. A replay returns the daily allowance snapshot at admission.
- Keep request tombstones and monthly/day counters without TTL. Only `RESULT#...`
  rows expire after 24 hours; reads enforce expiry even if DynamoDB TTL cleanup is
  delayed. Expired results cannot generate again under the original ID.
- A storage failure stops processing. Do not log exception details, prompts,
  generated text, credentials or tokens.

The future table requires a string partition key `pk`, no sort key, and TTL on
`expiresAt`. AI ledger rows contain hashes and accounting metadata, while result
rows contain report proposals for the 24-hour retry window. IAM permissions must
be restricted to this table and the supplied Gemini secret ARN.

The owner's monthly budget is USD 10. The proposed application limit is USD 8;
provider cap/auto-reload verification and application-limit confirmation remain
pending. Test prices are not production Gemini rates. Infrastructure charges and
provider accounting delays are outside this application allowance.

## Workflow boundaries

Swift controls preview, goal review, explicit Apply, cancellation and stale responses.
Python controls request accounting and generation. There is no LangGraph dependency
or autonomous loop in this foundation. Introduce backend graph orchestration only
when the product needs multiple persisted generation/tool steps; it must not own
or bypass the application's quota and idempotency rules.
