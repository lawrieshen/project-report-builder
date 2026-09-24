import SwiftUI

struct ProjectFilterPopover: View {
    @Binding var filter: ProjectBrowserFilter
    let linesOfBusiness: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filter Projects").font(.headline)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    statusFilters
                    Divider()
                    businessFilters
                }
                .toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            actionButtons
        }
        .padding()
        .frame(width: 280, height: 400)
    }

    @ViewBuilder
    private var statusFilters: some View {
        Text("Status").font(.headline)
        ForEach(ReportStatus.allCases, id: \.self) { status in
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
    private var businessFilters: some View {
        Text("Line of Business").font(.headline)
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
            Button("Clear") { filter = ProjectBrowserFilter() }
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
    }
}
