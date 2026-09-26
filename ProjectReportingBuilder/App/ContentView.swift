import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum Card {
        case duplicate(ProjectReport)
        case export
        case accessibility
        case livePreview
        case imagePreview(ImageAsset)
        case sourceContent
        case metric(EngineeringMetricDraft, Bool)
    }

    private let settings: AppSettingsStore?
    private let maintenance: RecoveryMaintenanceCoordinator?
    @State private var exportViewModel: ExportViewModel?
    @State private var focusedSection: ReportSection?
    @State private var card: Card?
    @State private var router: AppRouter
    @State private var browserViewModel: ProjectBrowserViewModel
    
    init(repository: ProjectRepository, assetFactory: ((UUID) -> any AssetRepository)? = nil,
         recoveryRepository: (any DraftRecoveryRepository)? = nil, settings: AppSettingsStore? = nil, session: AppSessionStore? = nil,
         maintenance: RecoveryMaintenanceCoordinator? = nil) {
        self.settings = settings
        self.maintenance = maintenance
        _router = State(initialValue: AppRouter(repository: repository, assetFactory: assetFactory, recoveryRepository: recoveryRepository, settings: settings, session: session, maintenance: maintenance))
        _browserViewModel = State(initialValue: ProjectBrowserViewModel(repository: repository))
    }
    
    var body: some View {
        content
            .frame(minWidth: 760, minHeight: 400)
            .task { await router.restoreSession() }
            .focusedSceneValue(\.reportActions, commandActions)
            .disabled(isShowingCard || maintenance?.isClearing == true)
            .accessibilityHidden(isShowingCard)
            .overlay {
                floatingCardOverlay
            }
            .alert("You have unsaved changes.", isPresented: $router.showingLeaveConfirmation) {
                Button("Save") { Task { await router.saveAndLeave() } }
                    .accessibilityIdentifier("leaveSave")
                Button("Discard", role: .destructive) { Task { await router.discardAndLeave() } }
                    .accessibilityIdentifier("leaveDiscard")
                Button("Cancel", role: .cancel) { router.cancelNavigation() }
                    .accessibilityIdentifier("leaveCancel")
            } message: {
                Text("Save your changes before leaving this report?")
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25),
                       value: isShowingCard)
    }
    
    private var commandActions: ReportActions {
        let editor = router.editor
        let available = !isShowingCard && !router.showingLeaveConfirmation && maintenance?.isClearing != true
            && !browserViewModel.isLoading && !browserViewModel.isSaving
            && editor?.isLoading != true && editor?.isSaving != true
            && editor?.isImporting != true && editor?.pendingRecovery == nil
        let hasReport = available && editor?.draft != nil
        return ReportActions(
            newProject: available ? { router.newProject() } : nil,
            openProject: available ? { router.showProjects() } : nil,
            save: available && editor?.canSave == true ? { Task { await editor?.save() } } : nil,
            preview: hasReport ? { card = .livePreview } : nil,
            export: hasReport ? { showExport() } : nil,
            accessibility: hasReport ? { card = .accessibility } : nil)
    }

    private var isShowingCard: Bool {
        router.showingNewProject || card != nil
    }

    @ViewBuilder
    private var floatingCardOverlay: some View {
        ZStack(alignment: .center) {
            if isShowingCard {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture { dismissCard() }
                    .accessibilityHidden(true)
                cardContent
                    .padding(AppSpacing.pageInset)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .clipped()
    }

    @ViewBuilder
    private var cardContent: some View {
        if router.showingNewProject {
            NewProjectCard(viewModel: browserViewModel, onDismiss: dismissNewProject,
                           onCreated: { project in
                dismissNewProject()
                router.openProject(id: project.id)
            })
        } else if let card {
            switch card {
            case .duplicate(let project):
                DuplicateProjectCard(project: project, viewModel: browserViewModel, onDismiss: dismissCard)
            case .export:
                if let draft = router.editor?.draft, let exportViewModel {
                    ExportPanelView(viewModel: exportViewModel, model: ReportPreviewModel(draft: draft),
                                    validation: AccessibilityValidationModel(draft: draft),
                                    reviewIssues: { self.card = .accessibility }, onDismiss: dismissCard)
                }
            case .accessibility:
                if let draft = router.editor?.draft {
                    AccessibilityPanelView(model: AccessibilityValidationModel(draft: draft),
                                           onDismiss: dismissCard) { section in
                        dismissCard()
                        focusedSection = section
                    }
                }
            case .livePreview:
                if let editor = router.editor, let model = editor.previewModel {
                    GeometryReader { geometry in
                        LivePreviewView(model: model,
                                        loadImage: { try await editor.imageData(for: $0, maximumPixelSize: 1200) },
                                        onDismiss: dismissCard)
                            .floatingCard(width: geometry.size.width, maxHeight: .infinity)
                    }
                }
            case .imagePreview(let asset):
                if let editor = router.editor {
                    ImagePreviewCard(asset: asset, editor: editor, onDismiss: dismissCard)
                }
            case .sourceContent:
                if let editor = router.editor {
                    ContentInputCard(editor: editor, onDismiss: dismissCard)
                }
            case .metric(let metric, let isAdding):
                if let editor = router.editor {
                    MetricEditorView(metric: metric, existingMetrics: editor.draft?.metrics ?? [],
                                     onDismiss: dismissCard) { confirmed in
                        if isAdding { return editor.addMetric(confirmed) }
                        return editor.updateMetric(confirmed)
                    }
                }

            }
        }
    }

    private func showExport() {
        guard let editor = router.editor else { return }
        exportViewModel = ExportViewModel(
            renderer: ReportExportRenderer { try await editor.imageData(for: $0, maximumPixelSize: 1440) },
            clipboard: MacClipboardService(), fileExporter: MacFileExportService(), sharing: MacShareService.shared)
        card = .export
    }

    private func dismissCard() {
        guard exportViewModel?.isBusy != true else { return }
        guard !browserViewModel.isSaving, router.editor?.isSaving != true else { return }
        if router.showingNewProject {
            dismissNewProject()
        } else {
            card = nil
        }
    }

    private func dismissNewProject() {
        browserViewModel.actionErrorMessage = nil
        router.showingNewProject = false
    }
    
    @ViewBuilder
    private var content: some View {
        workspaceDestination
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
    }
    
    @ViewBuilder
    private var workspaceDestination: some View {
        if let editor = router.editor {
            ReportEditorView(viewModel: editor, onBack: router.showProjects,
                             editMetric: { card = .metric($0, $1) },
                             addContent: { card = .sourceContent },
                             previewAsset: { card = .imagePreview($0) },
                             showPreview: { card = .livePreview },
                             showExport: showExport,
                             checkAccessibility: { card = .accessibility },
                             focusedSection: $focusedSection)
                .id(editor.projectID)
        } else {
            VStack(spacing: AppSpacing.field) {
                if let message = router.restorationMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                ProjectBrowserView(viewModel: browserViewModel,
                               openProject: { router.openProject(id: $0.id) },
                               newProject: router.newProject,
                               isCreatingProject: isShowingCard,
                               duplicateProject: { card = .duplicate($0) },
                               confirmBeforeDelete: settings?.settings.confirmBeforeDelete ?? true)
            }
        }
    }

    @ViewBuilder
    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                browserViewModel.actionErrorMessage = nil
                router.newProject()
            } label: {
                Label("New Project", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("newProjectButton")
            .disabled(browserViewModel.isLoading || browserViewModel.isSaving || router.editor?.isSaving == true || router.editor?.isImporting == true)
            .padding(AppSpacing.cardInset)
        }
    }
}

#Preview {
    ContentView(repository: InMemoryProjectRepository())
        .toolbar(removing: .title)
    
}
