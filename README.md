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
