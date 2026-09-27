import Foundation
import Observation

/// Stage source notes and reject results from older processing requests.
@MainActor
@Observable
final class ContentInputViewModel {
    var rawText = "" {
        didSet { clearResults() }
    }
    private(set) var isProcessing = false
    private(set) var suggestions: ReportContentSuggestions?
    private(set) var processingError: String?
    private(set) var isImportingText = false
    private(set) var importError: String?
    private let textReader: any SourceTextReading
    private var importGeneration = 0
    private let processor: any ContentProcessing
    private var generation = 0

    init(processor: (any ContentProcessing)? = nil,
         textReader: any SourceTextReading = SourceTextReader()) {
        self.textReader = textReader
        self.processor = processor ?? ContentProcessor()
    }

    var canProcess: Bool {
        !isProcessing && !isImportingText && !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Replace source notes only if the import is still current and the notes are unchanged.
    ///
    /// Ignore requests while importing or processing. Preserve existing notes on failure
    /// and expose the failure through `importError`.
    /// - Parameter url: The selected source file to read through the injected reader.
    func importText(from url: URL) async {
        guard !isImportingText, !isProcessing else { return }
        importGeneration += 1
        let request = importGeneration
        let originalText = rawText
        isImportingText = true
        importError = nil
        defer { if importGeneration == request { isImportingText = false } }
        do {
            let text = try await textReader.read(from: url)
            guard importGeneration == request, !Task.isCancelled, rawText == originalText else { return }
            rawText = text
        } catch is CancellationError {
            // Dismissed imports must not replace the user's notes.
        } catch {
            guard importGeneration == request, !Task.isCancelled else { return }
            importError = error.localizedDescription
        }
    }

    func prepareTextImport() { importError = nil }

    func reportImportFailure(_ error: Error) { importError = error.localizedDescription }

    /// Invalidate pending import and processing results while retaining source notes.
    ///
    /// This prevents late results from updating dismissed UI; it does not cancel
    /// the underlying service tasks.
    func cancelPendingWork() {
        importGeneration += 1
        isImportingText = false
        clearResults()
    }

    /// Stage suggestions for review without applying them to the report.
    ///
    /// Publish results only for the current request and expose failures through
    /// `processingError`. Empty input and overlapping work are ignored.
    func processText() async {
        guard canProcess else { return }
        generation += 1
        let request = generation
        let input = rawText
        isProcessing = true
        processingError = nil
        suggestions = nil
        defer { if generation == request { isProcessing = false } }
        do {
            let result = try await processor.process(text: input)
            guard generation == request, !Task.isCancelled else { return }
            suggestions = result
        } catch is CancellationError {
            // Closing or editing the input cancels review of the old request.
        } catch {
            guard generation == request else { return }
            processingError = "Unable to process this content. " + error.localizedDescription
        }
    }

    /// Discard suggestions and invalidate pending processing when source notes change.
    func clearResults() {
        generation += 1
        isProcessing = false
        suggestions = nil
        processingError = nil
    }
}
