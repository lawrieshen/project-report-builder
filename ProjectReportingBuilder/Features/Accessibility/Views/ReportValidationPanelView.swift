import SwiftUI

struct ReportValidationPanelView: View {
    let model: ReportValidationModel
    let onDismiss: () -> Void
    let goToSection: (ReportSection) -> Void
    @State private var viewModel = ReportValidationViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            header
            Text("Checks required fields, metric data, and accessibility of the current unsaved report.")
                .font(.callout).foregroundStyle(.secondary)
            Divider()
            ContentHeightScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    validationResults
                    Text("These checks do not certify WCAG compliance or inspect text inside images. Review image readability and descriptions manually.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, AppSpacing.inline)
            }
        }
        .floatingCard(width: 480)
        .task { await viewModel.validate(model: model) }
    }

    private var header: some View {
        HStack {
            Text("Report Validation").font(.title2)
            Spacer()
            Button("Recheck") { Task { await viewModel.validate(model: model) } }
                .disabled(viewModel.isChecking)
                .accessibilityIdentifier("recheckAccessibility")
            Button("Done", action: onDismiss)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("closeAccessibility")
        }
    }

    @ViewBuilder
    private var validationResults: some View {
        if viewModel.isChecking {
            ProgressView("Validating report…")
        } else if let report = viewModel.report {
            if report.isValid {
                ReportValidationSuccessView()
            } else {
                Text("\(report.issues.count) issues").font(.headline)
                ForEach(report.issues) { issue in
                    ReportValidationIssueRow(issue: issue) { goToSection(issue.section) }
                }
            }
        }
    }
}

struct ReportValidationIssueRow: View {
    let issue: ReportValidationIssue
    let goToSection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.inline) {
            Label(issue.severity.rawValue.capitalized, systemImage: issue.severity == .error ? "xmark.octagon" : "exclamationmark.triangle")
                .font(.callout.weight(.semibold))
            Text(issue.title).font(.headline)
            Text(issue.message).fixedSize(horizontal: false, vertical: true)
            Text(issue.section.title).font(.caption).foregroundStyle(.secondary)
            Button("Go to Section", action: goToSection)
                .accessibilityLabel("Go to \(issue.section.title)")
                .accessibilityIdentifier("accessibilitySection.\(issue.section.rawValue)")
        }
        .padding(AppSpacing.cardInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ReportValidationSuccessView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            Label("No validation issues found", systemImage: "checkmark.circle")
                .font(.headline)
                .accessibilityIdentifier("accessibilityAllClear")
            Text("Your report currently passes all enabled report checks.")
        }
    }
}
