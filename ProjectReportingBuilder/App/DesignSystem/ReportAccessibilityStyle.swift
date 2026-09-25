import SwiftUI

/// Keep the checked sRGB values identical to the colors used by the renderer.
struct ReportRGB: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    init(_ gray: Double) { red = gray; green = gray; blue = gray }
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}

struct ReportPalette {
    var name: String
    var background: ReportRGB
    var tile: ReportRGB
    var primary: ReportRGB
    var secondary: ReportRGB
}

/// Define the canonical report's typography, semantics, and opaque text surfaces.
struct ReportAccessibilityStyle {
    var bodySize: Double = 14
    var captionSize: Double = 12
    var headingSize: Double = 17
    var titleSize: Double = 30
    var metricSize: Double = 26
    var titleLevel = 1
    var sectionLevel = 2
    var headingSections = Set(ReportSection.allCases)
    var leadRole = "Lead EPM"
    var driRole = "Project DRI"
    var light = ReportPalette(name: "Light", background: ReportRGB(1), tile: ReportRGB(0.95),
                              primary: ReportRGB(0.1), secondary: ReportRGB(0.35))
    var dark = ReportPalette(name: "Dark", background: ReportRGB(0.1), tile: ReportRGB(0.16),
                             primary: ReportRGB(0.95), secondary: ReportRGB(0.75))
    static let canonical = ReportAccessibilityStyle()

    func palette(_ scheme: ColorScheme) -> ReportPalette { scheme == .dark ? dark : light }

    static func metricStatusLabel(_ status: MetricTargetStatus) -> String {
        switch status {
        case .met: return "Target Met"
        case .missed: return "Target Missed"
        case .notSet: return "Target Not Set"
        }
    }
}

/// Share the heading semantics used by the renderer and validation configuration.
struct ReportSectionHeading: View {
    let section: ReportSection
    var title: String? = nil
    var body: some View {
        Text(title ?? section.title)
            .font(.system(size: ReportAccessibilityStyle.canonical.headingSize, weight: .semibold))
            .accessibilityAddTraits(ReportAccessibilityStyle.canonical.headingSections.contains(section) ? .isHeader : [])
            .accessibilityHeading(ReportAccessibilityStyle.canonical.sectionLevel == 2 ? .h2 : .unspecified)
    }
}
