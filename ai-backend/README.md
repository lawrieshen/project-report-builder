# AI report composition service

This independent Python 3.12 service owns AI composition and budget accounting.
The existing Java service in `backend/` continues to own report CRUD and images.
The Swift Goal evaluator and UI state graph remain in the app.

**Foundation only: not deployed or enabled.** The Lambda entry point
`prb_ai.handler.lambda_handler` returns `AI_DISABLED` for valid authorized requests.
By default no Gemini client or API key is loaded. Explicit enablement requires complete
unexpired pricing configuration; disabled or malformed requests never load the secret.
The SDK adapter is implemented and tested offline. Verified model/pricing, deployment packaging,
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
| `gemini.py` | Official SDK adapter, complete prompt counting, single attempt and reasoning usage |
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

The owner's monthly budget is USD 10. The owner confirmed an application limit of USD 8, a provider cap of USD 10,
and disabled auto-reload. Runtime wiring enforces the application ceiling; deployment and live validation remain pending. Test prices are not production Gemini rates. Infrastructure charges and
provider accounting delays are outside this application allowance.

## Workflow boundaries

Swift controls preview, goal review, explicit Apply, cancellation and stale responses.
Python controls request accounting and generation. There is no LangGraph dependency
or autonomous loop in this foundation. Introduce backend graph orchestration only
when the product needs multiple persisted generation/tool steps; it must not own
or bypass the application's quota and idempotency rules.

## Gemini adapter (offline milestone)

`GeminiProvider` accepts a caller-owned `google.genai.Client` configured explicitly
with `vertexai=False` and an API key. The production handler constructs this
client only after request validation and explicit enablement with valid configuration. No secret is read by importing the adapter. Model and pricing come from
the server's `BudgetPolicy`; no production model or rate is selected in this stage.

Both SDK operations disable retries. Counting sends the complete
`generateContentRequest` (instructions, context and response schema) through public
`HttpOptions.extra_body`, because the Developer API SDK count config does not expose
those fields. Generation uses the same payload, one candidate and no tools. HTTP
timeouts are 3 seconds for counting and 18 seconds for generation; these are transport
timeouts, not an end-to-end wall-clock deadline. Lambda timeout and live latency
validation remain required before enablement.

Only a completed text candidate reaches strict proposal validation. Truncated,
blocked and tool responses fail. Usage includes candidate and thinking tokens;
missing or inconsistent totals retain the full budget reservation. Tests use the
real SDK with HTTP mock transport and a dummy key, with no live model calls.
Before enabling, verify model availability, structured-schema acceptance, full token
count behavior, current prices and end-to-end latency in the target Google project.

References: [Google SDK](https://googleapis.github.io/python-genai/),
[complete token counting request](https://ai.google.dev/api/tokens),
[structured output](https://ai.google.dev/gemini-api/docs/structured-output).

## Lambda package

Run `python3 scripts/package_lambda.py` from this directory. It exports runtime
requirements from the unchanged lockfile, verifies wheel hashes, installs only
Linux arm64 Python 3.12 wheels, checks native ELF architecture, and writes
`dist/ai-compose-lambda.zip` plus its SHA-256. It never copies the macOS virtualenv
or includes credentials. Source and dependencies are at the archive root.

CI imports the extracted artifact in the Python 3.12 arm64 Lambda container with
network disabled. A local cross-build verifies packaging and binary architecture;
it is not proof that the code ran in Lambda. Deployment must use the artifact from
a successful runtime smoke check. Upload it under an immutable SHA-based S3 key;
pass that key as `ArtifactKey` to the opt-in AI stack. Packaging does not deploy.

See [AWS Python packaging guidance](https://docs.aws.amazon.com/lambda/latest/dg/python-package.html).

## Runtime configuration and kill switch

`AI_ENABLED` defaults to false. Setting it to true requires `AI_USAGE_TABLE`,
`GEMINI_SECRET_ARN`, `AWS_REGION`, `AI_BUDGET_POLICY` (the strict BudgetPolicy JSON),
and `AI_PRICE_VALID_UNTIL` (an offset-aware ISO timestamp). No production prices are
provided: verify the model, input/output rates and validity period before setting
these values. The policy ceiling is USD 8; daily/input/output bounds remain 100/8000/2000.
Expired or malformed pricing fails before secret access. The secret must contain
`{"GEMINI_API_KEY":"..."}`. Never place its value in configuration files or commands.

The handler validates identity, route and payload before creating clients, and closes
clients at request completion. AWS calls have bounded timeouts and no SDK retries.
Changing `AI_ENABLED` to false prevents new generations after the configuration update;
it does not cancel invocations already running. Explicit production enablement remains
subject to the live acceptance gates in the implementation plan.
