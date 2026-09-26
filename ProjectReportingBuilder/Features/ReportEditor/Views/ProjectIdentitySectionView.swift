import SwiftUI

struct ProjectIdentitySectionView: View {
    @Binding var draft: ReportEditorDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            Text("Project Identity").font(.title3.bold())
            TextField("Project Code Name", text: $draft.codeName)
                .accessibilityIdentifier("reportCodeName")
            if let message = draft.codeNameError {
                Text(message).font(.caption).foregroundStyle(.red)
            }
            LineOfBusinessPicker(selection: $draft.lineOfBusiness)
                .accessibilityIdentifier("reportLineOfBusiness")
            if let message = draft.lineOfBusinessError {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        }
    }
}
