import SwiftUI

struct ContentView: View {
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @State private var showingNewProject = false
    @State private var browserViewModel: ProjectBrowserViewModel

    init(repository: ProjectRepository) {
        _browserViewModel = State(initialValue: ProjectBrowserViewModel(repository: repository))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
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
            .navigationTitle("Navigation")
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 260)
        } detail: {
            ProjectBrowserView(viewModel: browserViewModel, showingNewProject: $showingNewProject)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 400)
        .sheet(isPresented: $showingNewProject) {
            NewProjectSheet(viewModel: browserViewModel)
        }
    }
}

#Preview {
    ContentView(repository: InMemoryProjectRepository())
}
