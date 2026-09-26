import SwiftUI

struct ProjectEmptyStateView: View {
    let hasProjects: Bool
    let searchText: String
    let hasFilters: Bool
    let clearSearch: () -> Void
    let clearFilters: () -> Void
    
    var body: some View {
        ContentUnavailableView {
            emptyStateLabel
        } description: {
            emptyStateDescription
        } actions: {
            emptyStateActions
        }
    }
    
    @ViewBuilder
    private var emptyStateLabel: some View {
        if !hasProjects {
            Label("No projects yet", systemImage: "folder")
        } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Label("No projects match “" + searchText + "”", systemImage: "magnifyingglass")
        } else {
            Label("No projects match these filters.", systemImage: "line.3.horizontal.decrease")
        }
    }
    
    @ViewBuilder
    private var emptyStateDescription: some View {
        if !hasProjects {
            Text("Create your first project report.")
        }
    }
    
    @ViewBuilder
    private var emptyStateActions: some View {
        if !searchText.isEmpty {
            Button("Clear Search", action: clearSearch)
        }
        if hasFilters {
            Button("Clear Filters", action: clearFilters)
        }
    }
}
