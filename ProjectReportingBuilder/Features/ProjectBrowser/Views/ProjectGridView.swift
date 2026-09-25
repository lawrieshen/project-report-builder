import SwiftUI

struct ProjectGridView: View {
    private enum Layout {
        static let minimumCardWidth: CGFloat = 240
        static let maximumColumns = 3
    }

    let projects: [ProjectReport]
    let open: (ProjectReport) -> Void
    let delete: (ProjectReport) -> Void
    
    var duplicate: (ProjectReport) -> Void = { _ in }


    var body: some View {
        GeometryReader { geometry in
            // Cap the grid at three columns, with room for smaller windows.
            let availableWidth = max(0, geometry.size.width - AppSpacing.pageInset * 2)
            let columnWidth = Layout.minimumCardWidth + AppSpacing.gridGap
            let fittingColumns = Int((availableWidth + AppSpacing.gridGap) / columnWidth)
            let count = max(1, min(Layout.maximumColumns, fittingColumns))
            let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.gridGap), count: count)
            ScrollView {
                LazyVGrid(columns: columns, spacing: AppSpacing.gridGap) {
                    ForEach(projects) { project in
                        ProjectCardView(project: project,
                                        open: { open(project) },
                                        delete: { delete(project) }, duplicate: { duplicate(project) })
                    }
                }
                .padding(AppSpacing.pageInset)
            }
        }
    }
}
