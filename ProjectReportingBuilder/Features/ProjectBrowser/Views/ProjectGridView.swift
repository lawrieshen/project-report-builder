import SwiftUI

struct ProjectGridView: View {
    let projects: [ProjectReport]
    let open: (ProjectReport) -> Void
    let delete: (ProjectReport) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            // Cap the grid at three columns, with room for smaller windows.
            let count = max(1, min(3, Int((geometry.size.width - 32 + 16) / 256)))
            let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(projects) { project in
                        ProjectCardView(project: project,
                                        open: { open(project) },
                                        delete: { delete(project) })
                    }
                }
                .padding(16)
            }
        }
    }
}
