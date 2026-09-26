import SwiftUI

extension AppAppearance {
    /// Follow the system when no explicit appearance is selected.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
