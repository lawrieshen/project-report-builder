import Foundation

protocol ContentProcessing: Sendable {
    func process(text: String) async throws -> ReportContentSuggestions
}
