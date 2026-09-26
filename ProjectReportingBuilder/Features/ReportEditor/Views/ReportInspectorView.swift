import SwiftUI

struct ReportInspectorView: View {
    let project: ProjectReport
    var checkAccessibility: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.field) {
                Text("Report").font(.headline)
                LabeledContent("Status", value: project.status.displayName)
                Text("Last Updated").font(.headline)
                Text(project.updatedAt, format: .dateTime.day().month().year().hour().minute())
                Divider()
                Button("Check Accessibility", action: checkAccessibility)
                    .accessibilityIdentifier("checkAccessibility")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardInset)
        }
        .frame(width: 190)
        .background(.quaternary.opacity(0.3))
    }
}
