import SwiftUI

enum ProjectFilterGroup: String, CaseIterable {
    case status = "Status"
    case health = "Health"
    case business = "Business"
}

struct ProjectFilterCard: View {
    let group: ProjectFilterGroup
    @Binding var filter: ProjectBrowserFilter
    let linesOfBusiness: [String]
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            Text(group.rawValue).font(.headline)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.field) {
                    switch group {
                    case .status: statusFilters
                    case .health: healthFilters
                    case .business: businessFilters
                    }
                }
                .toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
            actionButtons
        }
        .floatingCard(width: 320, maxHeight: 400, padding: AppSpacing.cardInset)
    }
    
    @ViewBuilder
    private var statusFilters: some View {
        ForEach(ProjectStatus.allCases, id: \.self) { status in
            Toggle(status.displayName, isOn: Binding(
                get: { filter.statuses.contains(status) },
                set: { selected in
                    if selected {
                        filter.statuses.insert(status)
                    } else {
                        filter.statuses.remove(status)
                    }
                }
            ))
        }
    }
    
    @ViewBuilder
    private var healthFilters: some View {
        ForEach(RAGStatus.allCases, id: \.self) { health in
            Toggle(isOn: Binding(
                get: { filter.healthStatuses.contains(health) },
                set: { selected in
                    if selected {
                        filter.healthStatuses.insert(health)
                    } else {
                        filter.healthStatuses.remove(health)
                    }
                }
            )) {
                Label(health.displayName, systemImage: "circle.fill")
                    .foregroundStyle(health.color)
            }
        }
    }

    @ViewBuilder
    private var businessFilters: some View {
        if linesOfBusiness.isEmpty { Text("No business options available").foregroundStyle(.secondary) }
        ForEach(linesOfBusiness, id: \.self) { business in
            Toggle(business, isOn: Binding(
                get: { filter.linesOfBusiness.contains(business) },
                set: { selected in
                    if selected {
                        filter.linesOfBusiness.insert(business)
                    } else {
                        filter.linesOfBusiness.remove(business)
                    }
                }
            ))
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Button("Clear") {
                switch group {
                case .status: filter.statuses.removeAll()
                case .health: filter.healthStatuses.removeAll()
                case .business: filter.linesOfBusiness.removeAll()
                }
            }
            Spacer()
            Button("Done") { onDismiss() }
                .keyboardShortcut(.defaultAction)
                .onExitCommand(perform: onDismiss)
        }
    }
}
