import SwiftUI

struct ReportEditorView: View {
    @Bindable var viewModel: ReportEditorViewModel
    let onBack: () -> Void
    var editMetric: (EngineeringMetricDraft, Bool) -> Void = { _, _ in }
    var addContent: () -> Void = {}
    var previewAsset: (ImageAsset) -> Void = { _ in }
    var showPreview: () -> Void = {}
    var checkAccessibility: () -> Void = {}
    @Binding var focusedSection: ReportSection?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ReportEditorHeaderView(viewModel: viewModel, onBack: onBack, addContent: addContent, showPreview: showPreview)
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
                ReportInspectorView(project: project, checkAccessibility: checkAccessibility)
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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.section) {
                        ProjectIdentitySectionView(draft: draft).id(ReportSection.identity)
                        Divider()
                        HealthUrgencySectionView(draft: draft).id(ReportSection.health)
                        Divider()
                        MetricsSectionView(viewModel: viewModel, editMetric: editMetric).id(ReportSection.metrics)
                        Divider()
                        ExecutiveSummarySectionView(draft: draft).id(ReportSection.summary)
                        Divider()
                        AccountabilitySectionView(draft: draft).id(ReportSection.accountability)
                        Divider()
                        SupportingContentSectionView(editor: viewModel, preview: previewAsset).id(ReportSection.supportingContent)
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(AppSpacing.pageInset)
                }
                .accessibilityIdentifier("reportEditorScroll")
                .disabled(viewModel.isSaving)
                .onChange(of: focusedSection) { _, section in
                    guard let section else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut) { proxy.scrollTo(section, anchor: .top) }
                    focusedSection = nil
                }
            }
        }
    }
}

#Preview {
    let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                status: .active, createdAt: .now, updatedAt: .now)
    ReportEditorView(viewModel: ReportEditorViewModel(
        projectID: project.id, repository: InMemoryProjectRepository(projects: [project])), onBack: {}, focusedSection: .constant(nil))
        .frame(width: 900, height: 650)
}
