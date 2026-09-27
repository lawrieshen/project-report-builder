# Composition contract v1

`request.json`, `follow-up-request.json`, and `response.json` are shared Python/Swift test fixtures. This contract
is not deployed yet. The response envelope is produced by the server; the model
can produce only the nested `proposal` object.

The Pydantic models in `ai-backend/src/prb_ai/contracts.py` are the input/output validation boundary. Reject
unknown properties, scalar coercion, duplicate JSON keys, invalid UUIDs, and trailing
JSON. UUID casing is insignificant. Optional fields may be omitted or null. Required
arrays must be present, even when empty. Preserve array order in the request hash.

| Input | Limit |
| --- | --- |
| Encoded request | 64,000 UTF-8 bytes |
| Messages | 1–12, user/assistant only; last message must be user |
| Message text | 8,000 UTF-16 code units each |
| Draft summary | 20,000 UTF-16 code units |
| Names and draft enum text | 200 UTF-16 code units |
| Draft metrics | 100 unique IDs; incomplete numeric text is allowed |
| Goal | Policy 1, positive revision, supported options, unique required sections |

Context contains editable text and metric drafts. It never includes images, paths,
URLs, ownership, saved revisions, or lifecycle state. The provider must additionally
enforce the complete prompt token limit; byte/character limits are not token counts.

Each `proposedChanges` entry has one supported `field` and an `operation`:

- `set` requires a nonblank value. Enum values and YYYY-MM-DD dates must be valid.
- `clear` requires an absent/null value. `summaryType` cannot be cleared.
- A field absent from this list is unchanged. A field cannot appear twice.

`metricChanges` uses `add`, `update`, or `remove`. Add has no ID; the application
assigns it. Update/remove references one existing input metric, at most once.
Remove has no values; add/update requires values. Output numeric values must be
finite; a target and comparison must be supplied together. Comparisons and severity
use the Swift enum spellings (for example `lessThanOrEqual`, `p1`), not the report
storage API's `lte` and `P1` spellings. Resulting report validity remains a local
review step; incomplete reports are not silently populated with invented values.

Proposal bounds: 24,000 encoded bytes, 4,000-character assistant message, up to five
questions, ten warnings, and five unique semantic findings, each at most 1,000
characters. Findings are advisory and cannot set confirmation or completion.

The response echoes request ID, base/candidate version, goal ID/revision, and includes
the remaining daily allowance. A client must also check its local account session
and report identity before accepting it. Applying and cloud saving are separate steps.
