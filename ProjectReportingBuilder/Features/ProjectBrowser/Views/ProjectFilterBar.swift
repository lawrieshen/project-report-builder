import SwiftUI

struct ProjectFilterBar: View {
    private enum TagLayout {
        static let contentGap: CGFloat = 6
        static let leadingInset: CGFloat = 12
        static let trailingInset: CGFloat = 6
    }
    
    @Binding var searchText: String
    @Binding var filter: ProjectBrowserFilter
    let linesOfBusiness: [String]
    let showFilters: () -> Void
    
    var body: some View {
        HStack {
            Button {
                showFilters()
            } label: {
                Label(filter.isEmpty ? "Filter" : "Filter (Active)",
                      systemImage: "line.3.horizontal.decrease")
            }
            .fixedSize()
            .accessibilityIdentifier("projectFilterButton")
            ScrollView(.horizontal) {
                Spacer()
                activeFilterTags
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private var activeFilterTags: some View {
        HStack(spacing: AppSpacing.inline) {
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                filterTag("Search: " + searchText) {
                    searchText = ""
                }
            }
            ForEach(ProjectStatus.allCases.filter { filter.statuses.contains($0) }, id: \.self) { status in
                filterTag("Status: " + status.displayName) {
                    filter.statuses.remove(status)
                }
            }
            ForEach(RAGStatus.allCases.filter { filter.healthStatuses.contains($0) }, id: \.self) { health in
                filterTag("Health: " + health.displayName, statusColor: health.color) {
                    filter.healthStatuses.remove(health)
                }
            }
            ForEach(filter.linesOfBusiness.sorted(), id: \.self) { business in
                filterTag("Line of Business: " + business) {
                    filter.linesOfBusiness.remove(business)
                }
            }
        }
        .padding(.vertical, AppSpacing.compact)
    }
    
    @ViewBuilder
    private func filterTag(
        _ title: String,
        statusColor: Color? = nil,
        remove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: TagLayout.contentGap) {
            if let statusColor {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
            Text(title)
                .lineLimit(1)
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .padding(AppSpacing.compact)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove " + title)
            .help("Remove " + title)
        }
        .font(.callout)
        .padding(.leading, TagLayout.leadingInset)
        .padding(.trailing, TagLayout.trailingInset)
        .padding(.vertical, AppSpacing.compact)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
        .fixedSize()
    }
    
}
