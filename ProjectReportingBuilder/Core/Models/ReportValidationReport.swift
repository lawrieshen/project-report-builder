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

struct ReportValidationReport: Equatable {
    var issues: [ReportValidationIssue]
    var isValid: Bool { issues.isEmpty }
}
