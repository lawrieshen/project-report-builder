import SwiftUI

struct ProjectFilterBar: View {
    @Binding var filter: ProjectBrowserFilter
    let linesOfBusiness: [String]
    let newProject: () -> Void
    @State private var showingFilters = false
    
    var body: some View {
        HStack {
            Spacer()
            Button {
                showingFilters = true
            } label: {
                Label(filter.isEmpty ? "Filter" : "Filter (Active)",
                      systemImage: "line.3.horizontal.decrease")
            }
            .accessibilityIdentifier("projectFilterButton")
            .popover(isPresented: $showingFilters) {
                ProjectFilterPopover(filter: $filter, linesOfBusiness: linesOfBusiness)
            }
            Button(action: newProject) {
                Label("New Project", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityIdentifier("newProjectButton")
        }
    }
}
