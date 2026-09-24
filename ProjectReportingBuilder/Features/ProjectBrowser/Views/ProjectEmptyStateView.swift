import SwiftUI

struct ProjectEmptyStateView: View {
    let hasProjects: Bool
    let searchText: String
    let hasFilters: Bool
    let newProject: () -> Void
    let clearSearch: () -> Void
    let clearFilters: () -> Void
    
    var body: some View {
        ContentUnavailableView {
            if !hasProjects {
                Label("No projects yet", systemImage: "folder")
            } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("No projects match “" + searchText + "”", systemImage: "magnifyingglass")
            } else {
                Label("No projects match these filters.", systemImage: "line.3.horizontal.decrease")
            }
        } description: {
            if !hasProjects {
                Text("Create your first project report.")
            }
        } actions: {
            if !hasProjects {
                Button("New Project", action: newProject)
            } else {
                if !searchText.isEmpty {
                    Button("Clear Search", action: clearSearch)
                }
                if hasFilters {
                    Button("Clear Filters", action: clearFilters)
                }
            }
        }
    }
}
