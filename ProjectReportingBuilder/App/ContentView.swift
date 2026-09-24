import SwiftUI

struct ContentView: View {
    @State private var browserViewModel: ProjectBrowserViewModel

    init(repository: ProjectRepository) {
        _browserViewModel = State(initialValue: ProjectBrowserViewModel(repository: repository))
    }

    var body: some View {
        NavigationSplitView {
            List {
                Button {
                    browserViewModel.selectedProject = nil
                } label: {
                    Label("Projects", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("projectsNavigation")
                .listRowBackground(Color.accentColor.opacity(0.12))
            }
            .listStyle(.sidebar)
            .navigationTitle("Navigation")
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 260)
        } detail: {
            ProjectBrowserView(viewModel: browserViewModel)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 400)
    }
}

#Preview {
    ContentView(repository: InMemoryProjectRepository())
}
