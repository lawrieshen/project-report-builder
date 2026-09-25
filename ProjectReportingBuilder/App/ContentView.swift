import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            .disabled(router.showingNewProject)
            .accessibilityHidden(router.showingNewProject)
            .overlay {
                newProjectOverlay
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
                       value: router.showingNewProject)
    }
    
    @ViewBuilder
    private var newProjectOverlay: some View {
        ZStack(alignment: .trailing) {
            if router.showingNewProject {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if !browserViewModel.isSaving {
                            dismissNewProject()
                        }
                    }
                    .accessibilityHidden(true)
                    .transition(.opacity)
                
                NewProjectCard(
                    viewModel: browserViewModel,
                    onDismiss: dismissNewProject
                )
                .padding(24)
                .frame(width: 468)
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .clipped()
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 12)
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
            ReportEditorView(viewModel: editor, onBack: router.showProjects)
                .id(editor.projectID)
        } else {
            ProjectBrowserView(viewModel: browserViewModel,
                               openProject: { router.openProject(id: $0.id) },
                               newProject: router.newProject,
                               isCreatingProject: router.showingNewProject)
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
            .padding()
        }
    }
}

#Preview {
    ContentView(repository: InMemoryProjectRepository())
        .toolbar(removing: .title)
    
}
