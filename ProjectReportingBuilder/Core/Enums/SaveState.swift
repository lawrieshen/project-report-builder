import Foundation

nonisolated enum SaveState: Equatable {
    case saved
    case unsaved
    case saving
    case failed(String)

    var label: String {
        switch self {
        case .saved: "Saved"
        case .unsaved: "Unsaved Changes"
        case .saving: "Saving…"
        case .failed(let message): message
        }
    }
}
