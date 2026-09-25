import Foundation

enum AccessibilityIssueType: String, Codable {
    case missingAltText, colorOnlyStatus, lowContrast, smallText, missingHeading, emptyLabel
}

enum AccessibilitySeverity: String, Codable, CaseIterable {
    case error, warning, info
}

struct AccessibilityIssue: Identifiable, Equatable {
    let id: UUID
    var type: AccessibilityIssueType
    var severity: AccessibilitySeverity
    var title: String
    var message: String
    var section: ReportSection
}

struct AccessibilityReport: Equatable {
    var issues: [AccessibilityIssue]
    var isValid: Bool { issues.isEmpty }
}
