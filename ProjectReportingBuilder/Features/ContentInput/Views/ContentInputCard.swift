import SwiftUI
import UniformTypeIdentifiers

struct ContentInputCard: View {
    @Bindable var editor: ReportEditorViewModel
    let onDismiss: () -> Void
    @State private var model = ContentInputViewModel()
    @State private var selection = ContentSuggestionSelection()
    @State private var showingTextImporter = false
    @State private var importError: String?
    @State private var isImportingText = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text("Add Source Content").font(.title2)
            ScrollView {
                cardContent
            }
            actionButtons
        }
        .floatingCard(width: 560, maxHeight: .infinity)
        .fileImporter(isPresented: $showingTextImporter, allowedContentTypes: [.plainText]) { result in
            switch result {
            case .success(let url):
                Task {
                    isImportingText = true
                    defer { isImportingText = false }
                    do { model.rawText = try await SourceTextReader().read(from: url) }
                    catch { importError = error.localizedDescription }
                }
            case .failure(let error): importError = error.localizedDescription
            }
        }
        .onChange(of: model.suggestions) { _, suggestions in
            if let suggestions, let draft = editor.draft {
                selection = ContentSuggestionSelection(suggestions: suggestions, draft: draft)
            }
        }
        .onDisappear { model.clearResults() }
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
            if let importError { Text(importError).floatingCardError() }
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
                .frame(minHeight: 180)
                .accessibilityLabel("Raw Project Notes")
                .accessibilityIdentifier("sourceText")
                .disabled(model.isProcessing || isImportingText)
            Button("Import Text File") {
                importError = nil
                showingTextImporter = true
            }
            .disabled(model.isProcessing || isImportingText)
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
                .disabled(!model.canProcess || isImportingText)
                .accessibilityIdentifier("processContent")
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}
