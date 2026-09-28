import Foundation

/// Describe the user-assigned project scope without inferring it from staffing or health.
nonisolated enum ProjectSize: String, Codable, CaseIterable, Sendable {
    case small, medium, large

    var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }
}
