import SwiftUI

struct ContentView: View {
    private enum Layout {
        // The detail background extends beneath the title bar; its controls do not.
        static let titleBarClearance: CGFloat = 36
        static let detailInset: CGFloat = 12
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum Card {
        case sourceContent
        case filters
        case metric(EngineeringMetricDraft, Bool)
    }

    @State private var card: Card?
    @State private var router: AppRouter
    @State private var browserViewModel: ProjectBrowserViewModel
    
    init(repository: ProjectRepository) {
        _router = State(initialValue: AppRouter(repository: repository))
        _browserViewModel = State(initialValue: ProjectBrowserViewModel(repository: repository))
    }
    
    @ViewBuilder
    private var mainContent: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 400)
    }
    
    var body: some View {
        // Keep the split view at the root so sidebar rows stay below the toolbar.
        mainContent
            .disabled(isShowingCard)
            .accessibilityHidden(isShowingCard)
            .overlay {
                floatingCardOverlay
            }
            .alert("You have unsaved changes.", isPresented: $router.showingLeaveConfirmation) {
                Button("Save") { Task { await router.saveAndLeave() } }
                    .accessibilityIdentifier("leaveSave")
                Button("Discard", role: .destructive) { router.discardAndLeave() }
                    .accessibilityIdentifier("leaveDiscard")
                Button("Cancel", role: .cancel) { router.cancelNavigation() }
                    .accessibilityIdentifier("leaveCancel")
            } message: {
                Text("Save your changes before leaving this report?")
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25),
                       value: isShowingCard)
    }
    
    private var isShowingCard: Bool {
        router.showingNewProject || card != nil
    }

    @ViewBuilder
    private var floatingCardOverlay: some View {
        ZStack(alignment: .topTrailing) {
            if isShowingCard {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture { dismissCard() }
                    .accessibilityHidden(true)
                cardContent
                    .padding(AppSpacing.pageInset)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
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
            case .sourceContent:
                if let editor = router.editor {
                    ContentInputCard(editor: editor, onDismiss: dismissCard)
                }
            case .filters:
                ProjectFilterCard(filter: $browserViewModel.filter,
                                  linesOfBusiness: browserViewModel.linesOfBusiness,
                                  onDismiss: dismissCard)
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

    private func dismissCard() {
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
    private var sidebarContent: some View {
        List {
            Button {
                router.showProjects()
            } label: {
                Label {
                    Text("Projects")
                        .font(.system(size: 16))
                } icon: {
                    Image(systemName: "folder")
                        .font(.system(size: 18))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("projectsNavigation")
            .listRowBackground(Color.accentColor.opacity(0.12))
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarFooter
        }
        .background {
            Color(nsColor: .windowBackgroundColor)
                .overlay(Color.gray.opacity(0.12))
                .ignoresSafeArea()
        }
        .navigationTitle("Navigation")
        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 260)
    }
    
    @ViewBuilder
    private var detailContent: some View {
        workspaceDestination
            .padding(.top, Layout.titleBarClearance)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(Layout.detailInset)
            .ignoresSafeArea(.container, edges: .top)
            .background {
                Color(nsColor: .windowBackgroundColor)
                    .overlay(Color.gray.opacity(0.12))
                    .ignoresSafeArea()
            }
    }
    
    @ViewBuilder
    private var workspaceDestination: some View {
        if let editor = router.editor {
            ReportEditorView(viewModel: editor, onBack: router.showProjects,
                             editMetric: { card = .metric($0, $1) },
                             addContent: { card = .sourceContent })
                .id(editor.projectID)
        } else {
            ProjectBrowserView(viewModel: browserViewModel,
                               openProject: { router.openProject(id: $0.id) },
                               newProject: router.newProject,
                               isCreatingProject: router.showingNewProject,
                               showFilters: { card = .filters })
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
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityIdentifier("newProjectButton")
            .disabled(browserViewModel.isLoading || browserViewModel.isSaving || router.editor?.isSaving == true)
            .padding(AppSpacing.cardInset)
        }
    }
}

#Preview {
    ContentView(repository: InMemoryProjectRepository())
        .toolbar(removing: .title)
    
}
