import Foundation

enum ReportValidationIssueType: String, Codable {
    case invalidData, missingAltText, colorOnlyStatus, lowContrast, smallText, missingHeading, emptyLabel
}

enum ReportValidationSeverity: String, Codable, CaseIterable {
    case error, warning, info
}

struct ReportValidationIssue: Identifiable, Equatable {
    let id: UUID
    var type: ReportValidationIssueType
    var severity: ReportValidationSeverity
    var title: String
    var message: String
    var section: ReportSection
}

/// Collect report issues for presentation without changing the source data.
struct ReportValidationReport: Equatable {
    var issues: [ReportValidationIssue]
    /// Indicate that no issues of any severity were found, including warnings and information.
    var isValid: Bool { issues.isEmpty }
}
