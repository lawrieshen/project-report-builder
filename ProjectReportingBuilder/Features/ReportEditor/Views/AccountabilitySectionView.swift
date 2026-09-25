import SwiftUI

struct AccountabilitySectionView: View {
    @Binding var draft: ReportEditorDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            Text("Accountability").font(.title3.bold())
            TextField("Lead EPM", text: $draft.leadEPMName)
                .accessibilityIdentifier("reportLeadEPM")
            TextField("Project DRI", text: $draft.projectDRIName)
                .accessibilityIdentifier("reportDRI")
        }
    }
}
