import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingNewProject = false
    @State private var browserViewModel: ProjectBrowserViewModel
    
    init(repository: ProjectRepository) {
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
            .disabled(showingNewProject)
            .accessibilityHidden(showingNewProject)
            .overlay {
                newProjectOverlay
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25),
                       value: showingNewProject)
    }
    
    @ViewBuilder
    private var newProjectOverlay: some View {
        ZStack(alignment: .trailing) {
            if showingNewProject {
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
        showingNewProject = false
    }
    
    @ViewBuilder
    private var sidebarContent: some View {
        List {
            Button {
                browserViewModel.selectedProject = nil
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
        ProjectBrowserView(viewModel: browserViewModel, showingNewProject: $showingNewProject)
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
    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                browserViewModel.actionErrorMessage = nil
                browserViewModel.selectedProject = nil
                showingNewProject = true
            } label: {
                Label("New Project", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityIdentifier("newProjectButton")
            .disabled(browserViewModel.isLoading || browserViewModel.isSaving)
            .padding()
        }
    }
}

#Preview {
    ContentView(repository: InMemoryProjectRepository())
        .toolbar(removing: .title)
    
}
