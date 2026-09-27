import SwiftUI
import UniformTypeIdentifiers

/// Stage imported notes and apply only the suggestions selected by the user.
struct ContentInputCard: View {
    @Bindable var editor: ReportEditorViewModel
    let onDismiss: () -> Void
    @State private var model = ContentInputViewModel()
    @State private var selection = ContentSuggestionSelection()
    @State private var showingTextImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text("Add Source Content").font(.title2)
            ContentHeightScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.field) { cardContent }
            }
            actionButtons
        }
        .floatingCard(width: 560)
        .fileImporter(isPresented: $showingTextImporter, allowedContentTypes: [.plainText]) { result in
            switch result {
            case .success(let url):
                Task { await model.importText(from: url) }
            case .failure(let error): model.reportImportFailure(error)
            }
        }
        .onChange(of: model.suggestions) { _, suggestions in
            if let suggestions, let draft = editor.draft {
                selection = ContentSuggestionSelection(suggestions: suggestions, draft: draft)
            }
        }
        .onDisappear { model.cancelPendingWork() }
    }

    @ViewBuilder
    private var cardContent: some View {
        if let suggestions = model.suggestions, !suggestions.isEmpty, let draft = editor.draft {
            SuggestionReviewView(suggestions: suggestions, draft: draft, selection: $selection)
        } else {
            rawTextInput
            if model.isProcessing { ProgressView("Analyzing source content…") }
            if model.suggestions?.isEmpty == true {
                Text("No structured report information was detected.")
            }
            if let error = model.processingError {
                Text(error).floatingCardError()
            }
            if let importError = model.importError { Text(importError).floatingCardError() }
        }
    }

    @ViewBuilder
    private var rawTextInput: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            Text("Raw Project Notes").font(.headline)
            Text("Use one label per line: Project, Line of Business, Health, Milestone, Deadline, Summary Type, Summary, Lead EPM, or Project DRI.")
                .font(.callout).foregroundStyle(.secondary)
            Text("Example: Health: Amber\nDeadline: 2026-09-30\nSummary: Camera latency remains high.")
                .font(.caption).textSelection(.enabled)
            TextEditor(text: $model.rawText)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(AppSpacing.field)
                .frame(height: 180)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.secondary.opacity(0.35), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .accessibilityLabel("Raw Project Notes")
                .accessibilityIdentifier("sourceText")
                .disabled(model.isProcessing || model.isImportingText)
            Button("Import Text File") {
                model.prepareTextImport()
                showingTextImporter = true
            }
            .disabled(model.isProcessing || model.isImportingText)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Button("Cancel", action: onDismiss)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("cancelContent")
            Spacer()
            if let suggestions = model.suggestions, !suggestions.isEmpty {
                Button("Edit Source") { model.clearResults() }
                Button("Apply Selected") {
                    editor.applyContentSuggestions(suggestions, selection: selection)
                    onDismiss()
                }
                .disabled(selection.fields.isEmpty || editor.isSaving)
                .accessibilityIdentifier("applyContent")
                .keyboardShortcut(.defaultAction)
            } else {
                Button(model.processingError == nil ? "Process" : "Retry") {
                    Task { await model.processText() }
                }
                .disabled(!model.canProcess || model.isImportingText)
                .accessibilityIdentifier("processContent")
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}
