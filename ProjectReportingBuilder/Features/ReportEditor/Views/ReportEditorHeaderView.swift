import SwiftUI

struct ReportEditorHeaderView: View {
    @Bindable var viewModel: ReportEditorViewModel
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Label("Projects", systemImage: "chevron.left")
            }
            .accessibilityIdentifier("workspaceBack")
            VStack(alignment: .leading) {
                Text(viewModel.project?.codeName ?? "Report Workspace").font(.headline)
                if viewModel.isDirty {
                    Text("Unsaved Changes").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if viewModel.isSaving { ProgressView().controlSize(.small) }
            Button("Discard") { viewModel.discardChanges() }
                .disabled(!viewModel.isDirty || viewModel.isSaving)
                .accessibilityIdentifier("discardReport")
            Button("Save") { Task { await viewModel.save() } }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!viewModel.canSave)
                .accessibilityIdentifier("saveReport")
        }
        .padding()
    }
}
