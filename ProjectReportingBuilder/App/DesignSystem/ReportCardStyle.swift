import SwiftUI

/// Centralize the canonical card's geometry and visual hierarchy.
enum ReportCardStyle {
    static let standardWidth: CGFloat = 720
    static let minimumWidth: CGFloat = 280
    static let contentInset: CGFloat = 28
    static let cornerRadius: CGFloat = 20
    static let tileRadius: CGFloat = 12
    static let metricMinimumWidth: CGFloat = 180
    static let imageMinimumWidth: CGFloat = 220
    static let imageHeight: CGFloat = 180
    static let canvasInset: CGFloat = 24
    static let titleFont: Font = .system(size: ReportAccessibilityStyle.canonical.titleSize, weight: .bold, design: .rounded)
    static let metricFont: Font = .system(size: ReportAccessibilityStyle.canonical.metricSize, weight: .semibold, design: .rounded)
}
