import Foundation

/// Generate a reviewable proposal without changing or saving the editor draft.
protocol ReportComposing {
    func compose(_ request: CompositionRequest) async throws -> CompositionResponse
}

/// Preserve stable server failure codes so the UI can explain quota and retry states.
nonisolated struct CompositionServiceError: Error, Sendable {
    let code: CompositionErrorCode
}
