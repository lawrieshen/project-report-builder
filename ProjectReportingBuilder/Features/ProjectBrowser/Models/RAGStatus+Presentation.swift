import SwiftUI

extension RAGStatus {
    var displayName: String {
        switch self {
        case .green: return "On Track"
        case .amber: return "At Risk"
        case .red: return "Off Track"
        }
    }

    var color: Color {
        switch self {
        case .green: return .green
        case .amber: return .orange
        case .red: return .red
        }
    }
}
