import Foundation

/// Capture content semantics without owning or mutating the editor draft.
struct AccessibilityValidationModel: Equatable {
    var codeName: String
    var statusLabel: String?
    var metricNames: [String]
    var metricStatusLabels: [String]
    var assets: [ImageAsset]
    var visibleSections: [ReportSection]
    var roleLabels: [String]
}
