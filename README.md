# Project Report Builder

A native macOS application for creating strucutured, shareable project reporting snippet cards.

## Tech Stack

- Swift
- SwiftUI
- MVVM
- macOS

## Architecture

- Feature-based MVVM
- Repository abstraction for persistence
- Service layer for rendering, accessibility and export 

## Requirements

- macOS
- Xcode
## Report Workspace

Open a project card to view and edit its report in one screen. The workspace
supports project identity, health and milestone, executive summary, and
accountability. Status and template are read-only in the inspector.

- **Save** validates the draft and updates the report. Template, project identity,
  creation date, and existing card/person IDs are preserved.
- **Discard** restores the last saved values while keeping the workspace open.
- Leaving through Projects, the workspace back button, or New Project asks for
  Save / Discard / Cancel when there are unsaved changes. Failed saves keep the
  workspace open and preserve the draft.
- Code name and line of business are required. A milestone needs both a phase
  and deadline, or neither. Health, summary, and people may remain unset.
- Opening a project without a report card creates defaults only in memory;
  saving edits creates its single card. Repeated saves update that same card.

The app currently uses an in-memory repository. Saved changes last only for the
current app session; disk persistence, autosave, template editing, preview, and
export are not implemented. App-internal navigation is guarded; window closing
and quitting the app are not intercepted.

## Development and tests

```sh
./build.sh
./test.sh
./release.sh
```

`test.sh` runs unit and UI tests, excluding the launch performance test. UI tests
need macOS automation permission and an interactive desktop; avoid typing or
clicking while they run.

Workspace tests cover defaults, mapping, validation, template and identity
preservation, load/save failures, dirty state, discard, guarded navigation,
save/reopen, and browser refresh. ViewModels access reports through
`ProjectRepository.fetchProject(id:)`; `AppRouter` passes only project IDs and
coordinates navigation. Views edit `ReportEditorDraft` instead of stored data.

## Engineering Metrics

The Report Workspace includes an Engineering Metrics section between Health and
Summary. Add or click a metric to edit a temporary copy. **Save Metric** applies
that copy to the report draft; **Cancel** leaves the report unchanged. Use
**Save** in the workspace header to save the report to the repository.

Each metric has a name and current value, plus optional unit, target, and
severity (P0–P3 or Info). Targets support `<`, `≤`, `>`, `≥`, and `=`. Target status
and delta are calculated from the stored values, not saved as display strings.
Equality compares the exact stored Double values. Status includes text and an
icon, rather than color alone.

- Names must be unique within the report, ignoring case and surrounding spaces.
- Numeric input uses a decimal point; scientific notation is accepted. Commas,
  NaN, infinity, and values outside the finite Double range are rejected.
- Use the row menu to Edit, Move Up, Move Down, or Delete Metric. Array order is
  preserved across saves. Deletion changes the draft immediately; Discard can
  restore the last saved metrics.
- Metric changes participate in unsaved-navigation protection. Failed report
  saves preserve all metric edits, and saving never changes the template.
- Older report cards without a metrics field decode with an empty list.

Metrics tests cover model compatibility, comparison boundaries, formatting,
validation, duplicate names, stable IDs, ordering, failed saves, discard,
editing cancellation, and save/reopen UI workflows. Storage remains in memory.
