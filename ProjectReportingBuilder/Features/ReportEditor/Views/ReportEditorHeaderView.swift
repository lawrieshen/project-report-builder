import SwiftUI

struct ReportEditorHeaderView: View {
    @Bindable var viewModel: ReportEditorViewModel
    let onBack: () -> Void
    let addContent: () -> Void
    let showPreview: () -> Void
    let showExport: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.field) {
            navigationAndStatus
            Spacer()
            reportActions
            saveActions
        }
        .padding(.horizontal, AppSpacing.pageInset)
        .padding(.vertical, AppSpacing.cardInset)
    }

    @ViewBuilder
    private var navigationAndStatus: some View {
        Button(action: onBack) {
            Label("Projects", systemImage: "chevron.left")
        }
        .accessibilityIdentifier("workspaceBack")
        VStack(alignment: .leading) {
            Text(viewModel.project?.codeName ?? "Report Workspace").font(.headline)
            if viewModel.hasLoaded && viewModel.project != nil {
                Text(viewModel.saveState.label)
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("saveStatus")
            }
        }
    }

    @ViewBuilder
    private var reportActions: some View {
        Button("Preview", action: showPreview)
            .disabled(viewModel.draft == nil || viewModel.isLoading || viewModel.isImporting)
            .accessibilityIdentifier("openLivePreview")
        Button("Export", action: showExport)
            .disabled(viewModel.draft == nil || viewModel.isLoading || viewModel.isSaving || viewModel.isImporting)
            .accessibilityIdentifier("openExport")
        Button("Add Content", action: addContent)
            .disabled(viewModel.draft == nil || viewModel.isLoading || viewModel.isSaving || viewModel.isImporting)
            .accessibilityIdentifier("addContent")
    }

    @ViewBuilder
    private var saveActions: some View {
        if viewModel.isSaving { ProgressView().controlSize(.small) }
        Button("Discard") { Task { await viewModel.discardChanges() } }
            .disabled(!viewModel.isDirty || viewModel.isSaving)
            .accessibilityIdentifier("discardReport")
        Button("Save") { Task { await viewModel.save() } }
            .disabled(!viewModel.canSave)
            .accessibilityIdentifier("saveReport")
    }
}
