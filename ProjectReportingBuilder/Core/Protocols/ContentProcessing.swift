import Foundation

/// Derive reviewable field suggestions without modifying a report.
protocol ContentProcessing: Sendable {
    /// Extract suggestions from source text.
    ///
    /// - Parameter text: Notes supplied by the user.
    /// - Returns: Suggested values for review before applying them to a draft.
    /// - Throws: A processing error or cancellation from the implementation.
    func process(text: String) async throws -> ReportContentSuggestions
}
