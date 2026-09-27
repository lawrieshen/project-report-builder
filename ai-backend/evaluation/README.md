# Live composition acceptance

These ten synthetic cases exercise English, Traditional Chinese and Simplified
Chinese report composition. They cover missing information, numbers and units,
requests for support, unsupported enum values and instructions embedded in source
material. Passing schema validation alone does not demonstrate report quality.

## Preconditions

Before charged execution, deploy and verify the compose stack, its JWT route,
runtime secret permission, usage ledger and log retention. Select a supported
Gemini model and verify its current input/output (including thinking) rates and
pricing expiry. Configure the confirmed app-wide USD 8 monthly limit. Enable only
the approved test subject for acceptance; keep the production UI disabled.

The owner reported a Google USD 10 cap with automatic recharge disabled. This is
an owner confirmation, not an independently verified provider billing setting.

## Run

From `ai-backend`, validate inputs without authentication or network access:

```sh
.venv/bin/python scripts/evaluate_live.py
```

After the preconditions pass, execute the cases:

```sh
.venv/bin/python scripts/evaluate_live.py --execute
```

Enter the approved user's Cognito **access token** at the hidden prompt. Do not
paste tokens into chat, command arguments or tracked files. This tool calls the
authenticated report API, which owns budget accounting; it does not call Gemini
directly. The test requests contain synthetic data only.

The ignored `evaluation/results.json` stores the run ID before dispatch and each
response afterward. Keep it to resume safely. A resumed run reuses request IDs
and skips completed HTTP 200 cases. Changed cases or request fixtures are rejected
to prevent mixing evidence or reusing an ID for different content. Use a distinct
`--results evaluation/results-new.json` only for an intentional new, charged run.

A non-200 or uncertain transport outcome stops the run with nonzero exit status.
Inspect its matching server audit record before resuming. An expired cached result
cannot be recovered by continually retrying; keep the evidence and decide whether
a new charged run is necessary. No error response bodies or tokens are stored.

## Review evidence

For each case, record pass/fail and a brief reason for every listed `review` item.
Check the whole proposed report against the source, including unchanged fixture
fields. Confirm language, factual fidelity, units, missing information and handling
of embedded instructions. Do not count a clarifying question as a fabricated answer.

Match each request ID to `ai_generation` audit metadata. Record model, known input
and output tokens, conservative charge and outcome. Check the global ledger and
`ai_budget` metrics against reservations/settlements; an unknown usage outcome must
remain charged conservatively. Mark `usageReview` and `semanticReview` only after
this inspection. Compare observed request latency with the synchronous API timeout;
if it is unreliable, retain the asynchronous design gate in the main plan.

These cases do not prove UI acceptance. Separately exercise chat refinement,
partial selection, manual edits, confirmation invalidation, Apply, Undo, autosave,
reopen and export, plus cancellation, stale drafts, account changes and exhausted
quota. Verify normal report editing remains usable when AI is unavailable.

The budget alarm currently has no notification destination. A visible alarm state
alone is not proof of delivered alerts or a provider spending cap.
