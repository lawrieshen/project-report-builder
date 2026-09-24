import SwiftUI

struct ContentView: View {
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
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
