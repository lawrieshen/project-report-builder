import SwiftUI

struct ReportInspectorView: View {
    let project: ProjectReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Report").font(.headline)
                LabeledContent("Status", value: project.status.displayName)
                LabeledContent("Template", value: project.template.displayName)
                Text("Template is read-only").font(.caption).foregroundStyle(.secondary)
                Text("Last Updated").font(.headline)
                Text(project.updatedAt, format: .dateTime.day().month().year().hour().minute())
                Divider()
                Text("Sections").font(.headline)
                Text("Identity")
                Text("Health")
                Text("Metrics")
                Text("Summary")
                Text("Accountability")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .frame(width: 190)
        .background(.quaternary.opacity(0.3))
    }
}
