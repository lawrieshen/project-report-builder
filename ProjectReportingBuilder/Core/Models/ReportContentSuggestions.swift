import Foundation

/// Describe possible updates without modifying a report.
struct ReportContentSuggestions: Equatable, Sendable {
    var codeName: String?
    var lineOfBusiness: String?
    var ragStatus: RAGStatus?
    var milestonePhase: String?
    var milestoneDeadline: Date?
    var summaryType: SummaryType?
    var summaryMessage: String?
    var leadEPMName: String?
    var projectDRIName: String?

    var isEmpty: Bool { self == ReportContentSuggestions() }
}
