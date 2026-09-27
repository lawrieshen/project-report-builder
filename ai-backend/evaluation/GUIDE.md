# Live composition acceptance

These ten synthetic cases exercise English report composition, as requested by the
owner. They cover missing information, numbers and units,
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

Alternatively, sign in with the same account used in the app, without copying a
token. Start with one case before running the complete set:

```sh
.venv/bin/python scripts/evaluate_live.py --execute --sign-in --limit 1
```

This requires an interactive terminal. The password is hidden; credentials and
tokens are not written to results or printed. The runner supports the existing
public client's password flow; MFA/new-password challenges require the app and
token mode instead. With the backend disabled, a contract-defined disabled error
is expected and no Gemini generation occurs. Confirm the backend remains disabled
before using this as an authentication smoke test. Once controlled generation is
enabled, the same command can incur a charge. Remove `--limit 1` to run all cases.

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

After fixing a rejected case, select only the cases that need another charged run:

```sh
.venv/bin/python scripts/evaluate_live.py --execute --sign-in \
  --case en-no-invention --case en-concise \
  --results evaluation/results-follow-up.json
```

`--case` can be repeated. Selection preserves the full fixture fingerprint and runs
cases in fixture order; `--limit` applies after selection. A settled failed request
replays its failure, so an intentional fresh generation needs a new results file.
Retain previous evidence and respect the unchanged daily quota. A focused rerun
does not prove every case passed on the new deployment.

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

### Development app acceptance

In Xcode, edit the app scheme's **Run > Arguments > Environment Variables** and
set `PROJECT_REPORT_AI_COMPOSER` to `1`. Run a Debug build, sign in with the approved
test account, and open a disposable report. The editor header shows **Compose**.
Release builds ignore this variable, and Debug builds default to hiding the entry.
This switch does not bypass backend authentication or daily/monthly limits.

Use synthetic notes and record each outcome separately:

1. Send notes and inspect the candidate without applying; the report must stay unchanged.
2. Refine the candidate in chat, select a subset of changes, and edit candidate text.
   Changes must invalidate prior goal confirmation.
3. Review the goal checklist, Apply, then Undo; unrelated manual edits must survive.
4. Apply again and wait for the report save indicator. Close/reopen the report and
   export it, checking selected text and existing images are preserved.
5. Cancel an in-flight request, switch reports, and sign out; late responses must
   not affect another report or account.
6. Exercise exhausted quota or service failure and confirm manual editing/save/export
   remain usable. Record keyboard navigation and VoiceOver labels for the composer.

Respect the remaining daily quota; do not change limits to finish acceptance.
Local UI automation is not run by default; project instructions assign UI tests to CI.

The budget alarm template includes an SNS topic and optional `BudgetAlertEmail`
subscription. Delivery requires deployment, an owner-approved address and confirmed
subscription. A visible alarm state alone is not proof of delivered alerts or a
provider spending cap.
