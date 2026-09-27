import Foundation

/// Extract reviewable suggestions without mutating the destination report.
protocol ContentProcessing: Sendable {
    /// Analyze source notes for structured report fields.
    /// - Parameter text: The source notes to analyze.
    /// - Returns: Suggestions for the user to review before applying.
    /// - Throws: A processing or cancellation error.
    func process(text: String) async throws -> ReportContentSuggestions
}
