import SwiftUI

struct DuplicateProjectCard: View {
    let project: ProjectReport
    @Bindable var viewModel: ProjectBrowserViewModel
    let onDismiss: () -> Void
    @State private var name: String

    init(project: ProjectReport, viewModel: ProjectBrowserViewModel, onDismiss: @escaping () -> Void) {
        self.project = project
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        _name = State(initialValue: project.codeName + " Copy")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text("Duplicate Project").font(.title2.bold())
            Text("Copy the last saved report and its images into a separate project.")
                .foregroundStyle(.secondary)
            TextField("Project name", text: $name).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("duplicateProjectName")
            if let error = viewModel.actionErrorMessage { Text(error).foregroundStyle(.red) }
            actionButtons
        }
        .disabled(viewModel.isSaving)
        .floatingCard(width: 440)
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Button("Cancel", action: onDismiss)
            Spacer()
            if viewModel.isSaving { ProgressView().controlSize(.small) }
            Button("Duplicate") {
                Task {
                    if await viewModel.duplicateProject(project, codeName: name) { onDismiss() }
                }
            }
            .accessibilityIdentifier("confirmDuplicate")
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
