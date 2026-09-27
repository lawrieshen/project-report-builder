import Foundation

/// Generate a reviewable proposal without changing or saving the editor draft.
protocol ReportComposing {
    func compose(_ request: CompositionRequest) async throws -> CompositionResponse
}
