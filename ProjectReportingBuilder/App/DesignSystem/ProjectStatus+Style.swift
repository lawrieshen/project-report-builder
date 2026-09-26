import SwiftUI

extension ProjectStatus {
    var tint: Color {
        switch self {
        case .draft: .orange
        case .active: .blue
        case .archived: .gray
        }
    }
}
