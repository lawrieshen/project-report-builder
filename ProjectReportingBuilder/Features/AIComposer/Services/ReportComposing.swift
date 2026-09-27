import Foundation

/// Generate a reviewable proposal without changing or saving the editor draft.
protocol ReportComposing {
    func compose(_ request: CompositionRequest) async throws -> CompositionResponse
}

/// Preserve stable server failure codes so the UI can explain quota and retry states.
nonisolated struct CompositionServiceError: Error, Sendable {
    let code: CompositionErrorCode
}

extension CompositionErrorCode {
    var userMessage: String {
        switch self {
        case .disabled: return "AI composition is not enabled yet. Manual editing remains available."
        case .invalidInput: return "The request is too large or contains unsupported values. Shorten your notes or review the report fields."
        case .dailyQuota: return "Today's AI allowance is used up. Try after midnight UTC; manual editing remains available."
        case .budgetExhausted: return "The monthly AI allowance is used up. Manual editing and saving remain available."
        case .requestPending: return "The request is still processing. A new Send may use another allowance; your current candidate is unchanged."
        case .requestMismatch: return "This request ID was already used for different content. Start a new request."
        case .requestExpired: return "This request's saved result has expired. Send again to create a new request."
        case .rateLimited: return "The AI provider is busy. Wait before trying again."
        case .timeout: return "AI did not respond in time. Processing may still have incurred usage. Your candidate is unchanged."
        case .invalidOutput: return "AI returned a proposal we could not safely use. Review your notes and try again."
        case .unavailable: return "AI is temporarily unavailable. Your draft and previous candidate are unchanged."
        }
    }
}
