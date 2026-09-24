import SwiftUI

extension ReportStatus {
    var displayName: String {
        switch self {
        case .onTrack: return "On Track"
        case .atRisk: return "At Risk"
        case .blocked: return "Blocked"
        case .draft: return "Draft"
        case .archived: return "Archived"
        }
    }

    var color: Color {
        switch self {
        case .onTrack: return .green
        case .atRisk: return .orange
        case .blocked: return .red
        case .draft: return .secondary
        case .archived: return .gray
        }
    }
}
