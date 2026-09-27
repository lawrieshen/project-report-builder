# Project Report Builder

Turn project updates, engineering metrics, and images into polished,
shareable report cards — in one native macOS workspace.

Built as a proof of concept for enterprise project reporting.

## From update to report

**Create a project → Add content → Review validation → Preview → Copy or export**

- **Structure your update.** Capture project health, milestones, metrics,
  summaries, and ownership. Paste labeled notes or import a text file to
  suggest field values for review.
- **Make progress visible.** Compare metrics against targets, reorder them
  by dragging, and add supporting images with descriptions.
- **Catch issues early.** Automatic validation highlights incomplete data
  and supported accessibility issues as you edit.
- **Share a polished result.** Preview the report, copy it as an image,
  export PNG or HTML, or use the macOS share menu.
- **Keep work locally.** Local storage, autosave, and draft recovery help
  preserve work across sessions.

## Try it

Requires **macOS 26.2+** and **Xcode 26.2** (the version configured in CI).

1. Open `Project Report Builder.xcodeproj` in Xcode.
2. Select the **Project Report Builder** scheme and **My Mac** destination.
3. Configure your development signing team if needed, then run the app.
4. Choose **Create & Open**, add your report content, and open **Preview**
   or **Export** from the workspace.

## Engineering

Built with **Swift and SwiftUI**, using feature-based MVVM, repository
abstractions, and separate rendering and platform services.

```sh
bash build.sh   # Build the app
bash test.sh    # Run unit and UI tests
```

UI tests require an interactive macOS desktop and automation permission.
GitHub Actions is configured to build, analyze, run tests, and retain test
results. `release.sh` runs Release launch-performance tests; it does not
package a distributable app.

## POC scope

- One canonical report layout, with local storage and no cloud account required.
- Text suggestions use explicit labels, not AI interpretation of free-form text.
- Accessibility checks cover selected rules; passing is not a guarantee of
  WCAG conformance. PNG output does not retain HTML's semantic structure.
- Cloud storage is a future proposal, not an implemented feature.

## Further reading

- [Local Java cloud service and API contract](backend/README.md) — initial local
  milestone only; no cloud deployment or Cognito authentication yet.
- [Product behavior and engineering notes](docs/PRODUCT-AND-ENGINEERING.md)
- [Proposed cloud storage and identity scope](docs/CLOUD-STORAGE-PLAN.md)
