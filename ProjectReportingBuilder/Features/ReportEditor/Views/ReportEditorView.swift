import SwiftUI

struct ReportEditorView: View {
    @Bindable var viewModel: ReportEditorViewModel
    let onBack: () -> Void
    var editMetric: (EngineeringMetricDraft, Bool) -> Void = { _, _ in }
    var addContent: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            ReportEditorHeaderView(viewModel: viewModel, onBack: onBack, addContent: addContent)
            Divider()
            workspaceContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var workspaceContent: some View {
        if viewModel.isLoading || (!viewModel.hasLoaded && viewModel.loadError == nil) {
            ProgressView("Loading report…")
        } else if let error = viewModel.loadError {
            ContentUnavailableView {
                Label("Unable to load report", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") { Task { await viewModel.retry() } }
            }
        } else if let project = viewModel.project, let draft = Binding($viewModel.draft) {
            HStack(spacing: 0) {
                editorContent(draft: draft)
                Divider()
                ReportInspectorView(project: project)
            }
        } else {
            ContentUnavailableView("Project not found", systemImage: "folder.badge.questionmark",
                                   description: Text("This project may have been deleted."))
        }
    }

    @ViewBuilder
    private func editorContent(draft: Binding<ReportEditorDraft>) -> some View {
        VStack(spacing: 0) {
            if let error = viewModel.saveError {
                HStack {
                    Text(error).foregroundStyle(.red)
                    Button("Retry Save") { Task { await viewModel.save() } }
                        .disabled(!viewModel.canSave)
                }
                .padding(AppSpacing.cardInset)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    ProjectIdentitySectionView(draft: draft)
                    Divider()
                    HealthUrgencySectionView(draft: draft)
                    Divider()
                    MetricsSectionView(viewModel: viewModel, editMetric: editMetric)
                    Divider()
                    ExecutiveSummarySectionView(draft: draft)
                    Divider()
                    AccountabilitySectionView(draft: draft)
                }
                .textFieldStyle(.roundedBorder)
                .padding(AppSpacing.pageInset)
            }
            .disabled(viewModel.isSaving)
        }
    }
}

#Preview {
    let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                status: .active, createdAt: .now, updatedAt: .now)
    ReportEditorView(viewModel: ReportEditorViewModel(
        projectID: project.id, repository: InMemoryProjectRepository(projects: [project])), onBack: {})
        .frame(width: 900, height: 650)
}
