import SwiftUI

/// Edit summary text and intent directly in the parent-owned report draft.
struct ExecutiveSummarySectionView: View {
    @Binding var draft: ReportEditorDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            Text("Executive Summary").font(.title3.bold())
            Picker("Summary Type", selection: $draft.summaryType) {
                Text("Update").tag(SummaryType.update)
                Text("Blocker").tag(SummaryType.blocker)
                Text("Ask").tag(SummaryType.ask)
            }
            TextEditor(text: $draft.summaryMessage)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(AppSpacing.field)
                .frame(minHeight: 120)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                .accessibilityLabel("Summary Message")
                .accessibilityIdentifier("reportSummary")
        }
    }
}
