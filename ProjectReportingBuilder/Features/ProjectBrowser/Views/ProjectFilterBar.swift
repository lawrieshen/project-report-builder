import SwiftUI

struct ProjectFilterBar: View {
    @Binding var filter: ProjectBrowserFilter
    @Binding var presentedGroup: ProjectFilterGroup?

    var body: some View {
        HStack(spacing: AppSpacing.inline) {
            ForEach(ProjectFilterGroup.allCases, id: \.self) { group in
                ProjectFilterButton(group: group, filter: $filter,
                                    presentedGroup: $presentedGroup)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct ProjectFilterButton: View {
    let group: ProjectFilterGroup
    @Binding var filter: ProjectBrowserFilter
    @Binding var presentedGroup: ProjectFilterGroup?

    private var selectedNames: [String] {
        switch group {
        case .status: ProjectStatus.allCases.filter { filter.statuses.contains($0) }.map(\.displayName)
        case .health: RAGStatus.allCases.filter { filter.healthStatuses.contains($0) }.map(\.displayName)
        case .business: filter.linesOfBusiness.sorted()
        }
    }

    private var title: String {
        selectedNames.isEmpty ? group.rawValue : group.rawValue + ": " + selectedNames.joined(separator: ", ")
    }

    var body: some View {
        Button {
            presentedGroup = presentedGroup == group ? nil : group
        } label: {
            HStack(spacing: AppSpacing.compact) {
                if group == .health {
                    ForEach(RAGStatus.allCases.filter { filter.healthStatuses.contains($0) }, id: \.self) { status in
                        Circle()
                            .fill(status.color)
                            .frame(width: AppSpacing.inline, height: AppSpacing.inline)
                            .accessibilityHidden(true)
                    }
                }
                Text(title).lineLimit(1).truncationMode(.tail)
                Image(systemName: "chevron.down")
            }
            .padding(.horizontal, AppSpacing.inline)
            .padding(.vertical, AppSpacing.compact)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedNames.isEmpty ? Color.primary.opacity(0.05) : Color.blue.opacity(0.15))
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityIdentifier("projectFilter" + group.rawValue + "Button")
        .anchorPreference(key: ProjectFilterAnchors.self, value: .bounds) {
            [group: $0]
        }
    }
}

/// Locate filter buttons in the Browser's overlay coordinate space.
struct ProjectFilterAnchors: PreferenceKey {
    static var defaultValue: [ProjectFilterGroup: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [ProjectFilterGroup: Anchor<CGRect>],
                       nextValue: () -> [ProjectFilterGroup: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}
