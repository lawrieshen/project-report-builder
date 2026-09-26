# Project Report Builder

A native macOS application for creating structured, shareable project reporting snippet cards.

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

Use **Create & Open** in the compact, top-aligned New Project card to save a
project and open its workspace immediately. Failed creation keeps your input
in the card for retry.

Open a project card to view and edit its report in one screen. The workspace
supports project identity, health and milestone, executive summary, and
accountability. Project status is read-only in the inspector.

- **Save** validates the draft and updates the report. Autosave is enabled by
  default and uses the same validation and save pipeline after a 2-second pause.
  Project identity, creation date, and existing card/person IDs are preserved.
- **Discard** restores the last saved values while keeping the workspace open.
  It does not undo edits already committed by autosave.
- Leaving through Projects, the workspace back button, or New Project asks for
  Save / Discard / Cancel when there are unsaved changes. Failed saves keep the
  workspace open and preserve the draft.
- Code name and line of business are required. A milestone needs both a phase
  and deadline, or neither. Health, summary, and people may remain unset.
- Opening a project without a report card creates defaults only in memory;
  saving edits creates its single card. Repeated saves update that same card.

The app saves reports locally and keeps separate recovery copies of unsaved
edits. App-internal navigation is guarded; window closing and quitting are not
intercepted. Reopening a project offers any available recovery copy, or restores it
automatically when the recovery prompt preference is disabled.

## Development and tests

```sh
./build.sh
./test.sh
./release.sh
```

`test.sh` runs unit and UI tests, excluding the launch performance test. UI tests
need macOS automation permission and an interactive desktop; avoid typing or
clicking while they run.

Workspace tests cover defaults, mapping, validation, status and identity
preservation, load/save failures, dirty state, discard, guarded navigation,
save/reopen, and browser refresh. ViewModels access reports through
`ProjectRepository.fetchProject(id:)`; `AppRouter` passes only project IDs and
coordinates navigation. Views edit `ReportEditorDraft` instead of stored data.

## Engineering Metrics

The Report Workspace includes an Engineering Metrics section between Health and
Summary. Add or click a metric to edit a temporary copy. **Save Metric** applies
that copy to the report draft; **Cancel** leaves the report unchanged. Use
**Save** in the workspace header to save immediately, or let autosave commit
the valid draft after its configured delay.

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
  saves preserve all metric edits.
- Older report cards without a metrics field decode with an empty list.

Metrics tests cover model compatibility, comparison boundaries, formatting,
validation, duplicate names, stable IDs, ordering, failed saves, discard,
editing cancellation, and save/reopen UI workflows. Reports persist locally.

## Content & Asset Input

Use **Add Content** in the workspace header to type, paste, or import a UTF-8
plain-text file (up to 1 MB). The floating card processes explicit labels, one
per line. This MVP uses local rules, not AI or free-form language interpretation.

~~~text
Project: Titan
Line of Business: Camera
Health: Amber
Milestone: DVT
Deadline: 2026-09-30
Summary Type: blocker
Summary: Camera pipeline latency remains high.
Lead EPM: Jane Smith
Project DRI: Alex
~~~

Review **Current** and **Suggested** values before selecting **Apply Selected**.
Only empty fields start checked. Existing values require an explicit selection.
Unknown labels and invalid dates/statuses are ignored. Dates use YYYY-MM-DD;
health accepts Green/Amber/Red and summary type accepts Update/Blocker/Ask.
Source notes are temporary input and are not stored in the report. Processing
alone does not modify the draft. Applied suggestions participate in Save,
Discard, and unsaved-navigation protection. Milestones still require both a
phase and a deadline before the report can be saved.

The **Supporting Content** section accepts PNG, JPEG, and HEIC images through
the native file picker or file drag-and-drop. Images are validated by their
decoded format, limited to 20 MB each, and copied into app-managed storage.
Use each image's menu to preview, replace, move, or remove it. Alt text is editable
inline and may remain empty while drafting. Replacing an image preserves its
identity, alt text, and position. Duplicate filenames are allowed.

Reports store lightweight image references rather than image bytes. Image
changes remain in the draft until Save or autosave; Discard restores saved
references.
Failed saves preserve edits and files. Unused draft files are cleaned up, and
removed saved files are deleted only after a successful save. Cleanup failures
are shown separately without undoing a successful report save.

Reports and managed images persist across launches. Recovery copies also protect
images referenced by unsaved drafts.
PDF/OCR, remote URLs, automatic captions, and metric ingestion are outside
this feature.


## MVP scope and roadmap

The MVP uses one canonical report layout. Users manage structured content;
there is no template gallery or presentation-style selection. Live Preview
renders identity, health, metrics, summary, accountability, and supporting
images using this fixed layout.

Product flow:

~~~text
Structured Report
    → One canonical Apple-style layout
    → Live Preview
    → Accessibility Check
    → Export / Share
~~~

The domain remains ProjectReport with an optional SnippetCard. No template
property or template engine is needed. The reusable ReportCardView consumes
an immutable preview model and decoded images to produce the canonical layout. Historical JSON
template fields are ignored when decoding and are omitted from new output.

| Feature | Scope | Status |
| --- | --- | --- |
| 01 | Project Browser | Implemented |
| 02 | Report Workspace | Implemented |
| 03 | Metrics Editor | Implemented |
| 04 | Content & Asset Input | Implemented |
| 05 | Live Preview | Implemented |
| 06 | Accessibility Validation | Implemented |
| 07 | Export & Share | Implemented |
| 08 | Local Persistence & Recovery | Implemented |
| 09 | App Polish & Settings | Implemented |

Multiple layouts can be reconsidered when there is a concrete requirement.


## Live Preview

Choose **Preview** in the workspace header to see the current draft, including
unsaved changes. Preview uses a read-only floating workspace and never saves.
Closing it preserves edits; Discard restores the saved report as usual.

- The canonical card shows identity, health with text and color, milestone and
  derived countdown, metrics and target status, summary, images, and people.
- Empty optional sections are omitted. An empty code name shows Untitled Project.
  Invalid draft metrics show a correction message rather than disappearing.
- **Fit** adapts to the available window and fits the complete card; long cards
  can fit below 50%. **Actual Size** uses a 720-point card at 100%.
  Manual zoom is 50–200%, with horizontal and vertical scrolling.
- **System / Light / Dark** changes the preview canvas only.
- Images retain their order and alt text. Missing images display a labelled
  placeholder. Previews load bounded images rather than original-size files.
- Preview data is computed from the draft without repository reads or writes.
  Image loading is separate from the pure ReportCardView renderer.
- Countdown compares calendar days and refreshes every minute while open.

PNG and HTML export are available through the workspace Export action. Printing is not included.


## Accessibility Validation

Choose **Validate Report** in the workspace Inspector. The floating panel
checks the current unsaved draft without saving or changing dirty state.

- Missing or whitespace-only image alt text produces an error.
- Empty project and metric names, missing status text, and missing role labels
  produce actionable issues with severity and an affected section.
- **Go to Section** closes the panel and scrolls to the corresponding editor
  section. Fix the content, reopen the panel, and use **Recheck** as needed.
- Each opening checks a fresh draft snapshot. Results are not persisted or
  reused after editing; validation does not run on every keystroke.
- The canonical renderer shares heading markers, font sizes, semantic labels,
  and opaque sRGB palettes with the checker. Both Light and Dark palettes are
  checked for primary and secondary text on card and tile backgrounds.
- Status badges retain colored icons alongside high-contrast text. Visible
  report sections expose level-two headings below the level-one project title.

Text contrast uses the [W3C relative-luminance formula](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
and a conservative 4.5:1 threshold for all checked text. Body text is at least
14 pt and captions at least 12 pt at actual size; these font-size thresholds
are product policy, not WCAG requirements. Preview zoom does not change them.
Style issues require a renderer update, rather than an edit to report content.

The all-clear state means only that enabled checks passed. It is not WCAG
certification. The checker does not inspect pixels or text inside images,
judge alt-text quality, automate VoiceOver, tag exports, or block export.
Review image readability and description quality manually.


## Export & Share

Choose **Export** in the workspace toolbar. The floating card exports the current
unsaved draft; it never calls Save or changes the workspace dirty state.

- **PNG** uses the same `ReportCardView` as Live Preview at a fixed 720-point
  width. Standard produces 720-pixel-wide output; High Resolution uses 2× scale.
  Preview zoom has no effect on export resolution.
- **White** uses the light palette and an opaque white background. **System**
  captures the current app appearance. **Transparent** removes the card's outer
  background and keeps dark text and tile surfaces; choose a suitable destination
  background for readability.
- **HTML** is a standalone UTF-8 document with embedded PNG images, shared design
  tokens, semantic headings, status text, and escaped text/alt attributes. It
  follows the preview's content order; browser typography may differ from SwiftUI.
  PNG-only controls are hidden when HTML is selected.
- **Copy Image** always writes PNG. **Save to Finder** and **Share** use the selected
  format. Native sharing lists services available on the current Mac; no direct
  email, messaging, or cloud integrations are used.
- Save cancellation is neutral. “Share menu opened” confirms only presentation,
  not delivery. Share files stay available until the native service finishes or
  is cancelled; interrupted leftovers are cleaned up on a later launch.
- Every action validates the same current draft snapshot. Issues offer **Review
  Issues** or **Export Anyway**. Fixing content and exporting again runs a fresh
  check, rather than reusing a potentially stale report.
- Image bytes are loaded and decoded before rendering. Missing images fail with
  an actionable message instead of silently exporting placeholders. Output and
  decoded-image size limits prevent unbounded allocations; lower resolution or
  reduce content if a report exceeds these limits.

The export ViewModel coordinates rendering and destination protocols. AppKit
clipboard, save-panel, and sharing behavior lives under `Platform/`. PNG rendering
is read-only and runs on the main actor; no project persistence is involved.

PDF, printing, batch export, and export history remain outside this feature.


## Local Persistence & Recovery

Production stores versioned JSON and managed images in the app's Application
Support directory. Sandboxed builds resolve this inside the app container;
Settings → Storage shows the actual location, counts, and size, and can
reveal it in Finder. No demo projects are created automatically.

- **Save** and enabled autosave atomically replace the canonical report. Failed
  saves retain the draft and its dirty state. Files are read and written by a background actor.
- **Recovery** writes a separate snapshot about 1.5 seconds after editing pauses.
  It preserves raw input, including incomplete metrics, and does not update the
  saved report or clear Unsaved Changes. An abrupt exit before the debounce
  completes can lose the most recent edits.
- On reopening a project, **Restore** loads recovered input as an unsaved draft;
  **Discard Recovery** keeps the last canonical save. Save and Discard cancel
  queued backups and remove obsolete recovery data. Old snapshots are tied to
  the canonical content revision and cannot overwrite a newer save.
- Imported images are copied into each project's Assets directory; references
  are relative to that managed directory. Files still referenced by a saved
  report or recovery copy are protected from draft cleanup.
- **Duplicate** copies the last saved report and its images, with new project,
  card, metric, person, and asset identities. Unsaved recovery is not duplicated.
- **Delete** permanently removes the project, its images, and recovery. Pending
  cleanup after an interrupted deletion is retried when projects are loaded.
  **Archive** only changes status and retains data and recovery; the content
  revision timestamp remains unchanged.
- Corrupt or unsupported project documents produce warnings while valid projects
  remain available. They are not silently overwritten. Only the initial schema
  is supported; future versions require an explicit migration.

The app has one editing window to avoid simultaneous edits to the same recovery
copy. Previews keep using in-memory repositories. Debug UI tests receive unique
storage directories and preferences suites so they never read or modify production
projects or preferences. Existing explicit-save UI workflows disable autosave and
workspace restoration in their isolated suite; App Polish tests exercise the
production defaults.

Cloud synchronization, external storage relocation, version history, and remote
backup are not included. A local recovery copy is not protection against losing
this Mac or its disk.


## App Polish & Settings

Open the native **Settings…** window with **⌘,**. General, Appearance, Shortcuts,
Window, Storage, and About share one persisted preference store. Changes apply
immediately; launch preferences take effect on the next launch. About reads the
installed app's version and build metadata.

| Preference | Default | Behavior |
| --- | --- | --- |
| Autosave | On | Save valid drafts to canonical local storage |
| Autosave delay | 2 seconds | Choose 1, 2, or 5 seconds after the last edit |
| Appearance | System | Follow macOS, or choose Light or Dark |
| Restore workspace after unexpected termination | On | Reopen the last project only after an interrupted session |
| Confirm project deletion | On | Turning this off makes project deletion immediate |
| Ask before restoring recovery | On | Turning this off restores available drafts automatically |

**Restore Defaults** resets preferences without deleting or resetting projects. Session state
stores the last project ID separately from reports. Missing projects fall back
to the browser; a failed lookup shows a message. Startup restoration never
replaces navigation the user has already started. The app retains one editing
window and uses native macOS window restoration for geometry. Floating cards
are not restored.

Autosave cancels and restarts its timer on edits. Manual Save cancels a pending
timer and saves immediately through the same pipeline. Invalid drafts remain
unsaved and recoverable. Failed saves keep all edits, show **Autosave failed** or
**Save failed**, and offer **Retry Save**. They do not retry endlessly. The header
shows **Saved**, **Unsaved Changes**, or **Saving…**. With autosave off, only
recovery snapshots are written until an explicit Save.

Preview, validation, and export do not explicitly save reports. A pending
autosave can still finish while these read-only panels are open. To keep edits
uncommitted while reviewing them, turn autosave off.

Storage shows project, asset, and recovery counts. **Clear Recovery Drafts…**
always requires confirmation, even when project deletion confirmation is off.
It cancels pending workspace writes and removes recovery documents only. Saved
reports, images, and current in-memory edits remain. Automatic backup and save
resume after the next edit, so cleared snapshots are not immediately recreated.

| Shortcut | Action |
| --- | --- |
| ⌘N | New Project |
| ⌘O | Open Project Browser |
| ⌘S | Save Report |
| ⌘P | Preview Report |
| ⌘E | Export Report |
| ⇧⌘A | Validate Report |
| ⌘, | Settings |
| ⌘W | Close the active window |

Shortcuts are fixed and scoped to the focused editing window. Report commands
are unavailable while a floating card, recovery decision, navigation decision,
or blocking operation is active. **⌘A** remains Select All. System accent color
and Reduce Motion continue to follow macOS.

Tests cover preference persistence and defaults, appearance mapping, autosave
debounce/cancellation/failure, manual save concurrency, recovery preservation and
cleanup, restoration fallback, and native Settings/shortcut/relaunch workflows.

Normal app launches open the Project Browser. Quitting with ⌘Q marks the
session as normally terminated; closing a window does not. An unfinished
session marker enables workspace restoration after a crash, force quit, or
other unexpected termination, subject to the restoration preference. Saved
recovery drafts remain available when a project is opened manually.

### Line of Business options

New projects use five predefined product lines: iPhone, Mac, iPad,
Wearables, Home and Accessories, and Services. These follow Apple's public
[FY2025 financial reporting categories](https://www.apple.com/newsroom/pdfs/fy2025-q4/FY25_Q4_Consolidated_Financial_Statements.pdf),
not an internal organization chart.

Existing custom values are not offered in pickers or Browser filters.
Opening an older project does not rewrite its stored data. Select a supported
product line before saving; autosave also waits until the draft is valid.

### Report Validation

Validate Report checks the current unsaved draft for required identity fields,
a supported product line, complete milestone data, and valid metric values
and names, alongside the existing accessibility and readability checks.
Issues link back to their editor sections. Optional sections remain optional.
Export uses the same report checks and retains its explicit Export Anyway
confirmation; saving still requires valid report data.

Milestone phases use Prototype, EVT, DVT, PVT, and Mass Production. These are
hardware-oriented presets, informed by Apple's public
[engineering roles](https://jobs.apple.com/en-us/details/200664229-3401/ee-design-test-engineer)
and [iPhone development roles](https://jobs.apple.com/en-ng/details/200588442-3715/iphone-system-electrical-engineer),
not a claim to reproduce every internal workflow. Milestones remain optional;
when set, a supported phase and deadline are both required. Existing custom
phases are preserved on disk but require reselection before saving.
