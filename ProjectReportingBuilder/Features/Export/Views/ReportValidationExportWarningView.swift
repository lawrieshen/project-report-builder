import SwiftUI

struct ReportValidationExportWarningView: View {
    let issueCount: Int
    let review: () -> Void
    let proceed: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            Label(issueCount == 1 ? "1 validation issue remains" : "\(issueCount) validation issues remain",
                  systemImage: "exclamationmark.triangle")
                .font(.headline)
                .accessibilityIdentifier("exportAccessibilityWarning")
            Text("You can still export, but fixing these issues is recommended.")
            HStack {
                Button("Review Issues", action: review).accessibilityIdentifier("reviewExportIssues")
                Button("Export Anyway", action: proceed).accessibilityIdentifier("exportAnyway")
                Button("Cancel", action: cancel)
            }
        }
        .padding(AppSpacing.cardInset)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}
