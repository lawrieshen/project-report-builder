import SwiftUI

struct ProjectFilterBar: View {
    @Binding var searchText: String
    @Binding var filter: ProjectBrowserFilter
    let linesOfBusiness: [String]
    @State private var showingFilters = false
    
    var body: some View {
        HStack {
            ScrollView(.horizontal) {
                activeFilterTags
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                showingFilters = true
            } label: {
                Label(filter.isEmpty ? "Filter" : "Filter (Active)",
                      systemImage: "line.3.horizontal.decrease")
            }
            .fixedSize()
            .accessibilityIdentifier("projectFilterButton")
            .popover(isPresented: $showingFilters) {
                ProjectFilterPopover(filter: $filter, linesOfBusiness: linesOfBusiness)
            }

        }
    }

    @ViewBuilder
    private var activeFilterTags: some View {
        HStack(spacing: 8) {
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                filterTag("Search: " + searchText) {
                    searchText = ""
                }
            }
            ForEach(ReportStatus.allCases.filter { filter.statuses.contains($0) }, id: \.self) { status in
                filterTag("Status: " + status.displayName, statusColor: status.color) {
                    filter.statuses.remove(status)
                }
            }
            ForEach(filter.linesOfBusiness.sorted(), id: \.self) { business in
                filterTag("Line of Business: " + business) {
                    filter.linesOfBusiness.remove(business)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func filterTag(
        _ title: String,
        statusColor: Color? = nil,
        remove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
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
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove " + title)
            .help("Remove " + title)
        }
        .font(.callout)
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
        .fixedSize()
    }

}
