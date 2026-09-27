import SwiftUI

struct ReportInspectorView: View {
    let project: ProjectReport
    let draft: ReportEditorDraft
    let goToSection: (ReportSection) -> Void
    @State private var validation: ReportValidationViewModel

    init(project: ProjectReport, draft: ReportEditorDraft,
         goToSection: @escaping (ReportSection) -> Void,
         checker: any ReportValidating = ReportValidator()) {
        self.project = project
        self.draft = draft
        self.goToSection = goToSection
        _validation = State(initialValue: ReportValidationViewModel(checker: checker))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.field) {
                reportMetadata
                Divider()
                validationResults
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardInset)
        }
        .frame(width: 190)
        .background(.quaternary.opacity(0.3))
        .task(id: draft) {
            await validation.validate(model: ReportValidationModel(draft: draft))
        }
    }

    @ViewBuilder
    private var validationResults: some View {
        Text("Report Validation").font(.headline)
        if validation.isChecking || validation.report == nil {
            ProgressView("Validating…")
        } else if let report = validation.report {
            Image(systemName: report.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(report.isValid ? Color.green : Color.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.inline)
                .accessibilityLabel(report.isValid ? "Validation passed" : "Validation issues found")
            if report.isValid {
                Text("No issues found")
                    .accessibilityIdentifier("reportValidationAllClear")
            } else {
                Text("\(report.issues.count) issues").font(.subheadline.bold())
                ForEach(report.issues) { issue in
                    issueCard(issue)
                }
            }
            Text("Checks report data and accessibility; does not certify WCAG compliance.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var reportMetadata: some View {
        Text("Report").font(.headline)
        LabeledContent("Status") {
            ProjectStatusBadge(status: project.status)
        }
        Text("Last Updated").font(.headline)
        Text(project.updatedAt, format: .dateTime.day().month().year().hour().minute())
    }

    @ViewBuilder
    private func issueCard(_ issue: ReportValidationIssue) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(issue.severity.rawValue.capitalized)
            Text(issue.title).fontWeight(.semibold)
            Text(issue.message)
            Button("Go to " + issue.section.title) { goToSection(issue.section) }
                .accessibilityIdentifier("reportValidationSection." + issue.section.rawValue)
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.inline)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        }
    }
}

#Preview("Valid Report") {
    let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone",
                                status: .active, createdAt: .now, updatedAt: .now)
    ReportInspectorView(project: project, draft: ReportEditorDraft(project: project),
                        goToSection: { _ in })
        .frame(height: 500)
}

#Preview("Validation Issues") {
    let project = ProjectReport(id: UUID(), codeName: "", lineOfBusiness: "Camera",
                                status: .draft, createdAt: .now, updatedAt: .now)
    ReportInspectorView(project: project, draft: ReportEditorDraft(project: project),
                        goToSection: { _ in })
        .frame(height: 500)
}
