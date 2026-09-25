import SwiftUI

struct SuggestionReviewView: View {
    let suggestions: ReportContentSuggestions
    let draft: ReportEditorDraft
    @Binding var selection: ContentSuggestionSelection

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text("Suggested Updates").font(.headline)
            Text("Existing values are unchecked. Choose each value you want to replace.")
                .foregroundStyle(.secondary)
            ForEach(ContentSuggestionField.allCases) { field in
                if let proposed = field.suggestedValue(in: suggestions) {
                    VStack(alignment: .leading, spacing: AppSpacing.inline) {
                        Toggle(field.title, isOn: Binding(
                            get: { selection.fields.contains(field) },
                            set: { selected in
                                if selected { selection.fields.insert(field) }
                                else { selection.fields.remove(field) }
                            }
                        ))
                        .accessibilityIdentifier("suggestion." + field.rawValue)
                        Text("Current: " + currentValue(field))
                            .foregroundStyle(.secondary)
                        Text("Suggested: " + proposed)
                    }
                    Divider()
                }
            }
        }
        .toggleStyle(.checkbox)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func currentValue(_ field: ContentSuggestionField) -> String {
        let value = field.currentValue(in: draft)
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : value
    }
}
