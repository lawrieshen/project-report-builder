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
    private let processor: any ContentProcessing
    private var generation = 0

    init(processor: (any ContentProcessing)? = nil) {
        self.processor = processor ?? ContentProcessor()
    }

    var canProcess: Bool {
        !isProcessing && !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

    func clearResults() {
        generation += 1
        isProcessing = false
        suggestions = nil
        processingError = nil
    }
}
