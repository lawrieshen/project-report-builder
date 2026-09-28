import Foundation

/// Capture only the immutable content needed to render a report.
struct ReportPreviewModel: Equatable {
    let codeName: String
    let lineOfBusiness: String
    var projectSize: ProjectSize? = nil
    let ragStatus: RAGStatus?
    let milestonePhase: String?
    let milestoneDeadline: Date?
    let metrics: [ReportPreviewMetric]
    let summaryType: SummaryType
    let summaryMessage: String
    let leadEPMName: String?
    let projectDRIName: String?
    let assets: [ImageAsset]
}

/// Keep invalid draft metrics visible instead of silently dropping them.
struct ReportPreviewMetric: Identifiable, Equatable {
    let id: UUID
    let name: String
    let metric: EngineeringMetric?
    let validationMessage: String?
}
