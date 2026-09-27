# Cloud-primary storage

Cloud reports are the source of truth. Local storage holds account-scoped image
caches and recovery drafts, not an independent report library. The current
manual transfer flow remains available until the final application switch.

## Behavior

- Require sign-in before opening the cloud browser. Restore saved credentials on
  launch; distinguish a network failure from an expired session.
- Keep report IDs and server revisions when opening reports. Duplicate creates
  a new ID. Paginate the browser without losing reports.
- Save one snapshot per report at a time. Only acknowledge Saved after the API
  confirms the write; later edits remain dirty. Retain recovery drafts on error.
- On revision conflict stop autosave and preserve edits. Reload explicitly or
  save a separate copy; never adopt a newer revision and overwrite silently.
- Upload only changed images. Cache verified downloads under the signed-in
  account and preserve images needed by recovery drafts.
- Before logout preserve pending edits. Invalidate in-flight operations so old
  responses cannot repopulate a new session or cross account boundaries.
- Migrate old local projects explicitly, preserving IDs and known revisions.
  Retrying migration must not create duplicates. Keep original local files.
- Delete with an expected revision and retain a tombstone to prevent delayed
  saves from resurrecting a deleted report. Do not delete S3 objects immediately.

## Implementation sequence

1. Document behavior and reconcile implementation status.
2. Add revision-safe deletion to the API and infrastructure.
3. Implement identity-preserving cloud project storage.
4. Reuse uploaded images and cache downloads.
5. Protect autosave, conflicts and recovery drafts.
6. Scope navigation and in-flight work to authenticated sessions.
7. Add explicit local migration with per-project results.
8. Switch production defaults, update UI tests and deployment documentation.

Build and relevant non-UI tests must pass before each commit. UI tests run in
CI. Deploy the compatible API before enabling cloud-primary in the app.

## Acceptance

Verify create, reopen, edit, archive, duplicate, delete, image preview and export.
Exercise interrupted saves, token expiry, concurrent revisions, logout during a
request, recovery after restart and migration retries. Keep test-only local
repositories for deterministic unit and UI tests. Automatic S3 orphan cleanup
is deferred; never apply blanket expiry to referenced images.
