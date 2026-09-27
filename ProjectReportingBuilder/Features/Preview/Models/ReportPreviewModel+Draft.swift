import Foundation

extension ReportPreviewModel {
    /// Build a display snapshot without discarding invalid metric rows.
    /// - Parameter draft: The current editor values, including incomplete input.
    init(draft: ReportEditorDraft) {
        codeName = draft.codeName.trimmingCharacters(in: .whitespacesAndNewlines)
        lineOfBusiness = draft.lineOfBusiness.trimmingCharacters(in: .whitespacesAndNewlines)
        ragStatus = draft.ragStatus
        milestonePhase = Self.nonempty(draft.milestonePhase)
        milestoneDeadline = draft.milestoneDeadline
        metrics = draft.metrics.map { item in
            do {
                if let error = item.validationError(in: draft.metrics) {
                    throw MetricValidationError(message: error)
                }
                return ReportPreviewMetric(id: item.id, name: item.name,
                                           metric: try item.makeMetric(), validationMessage: nil)
            } catch {
                return ReportPreviewMetric(id: item.id, name: Self.nonempty(item.name) ?? "Untitled metric",
                                           metric: nil, validationMessage: error.localizedDescription)
            }
        }
        summaryType = draft.summaryType
        summaryMessage = draft.summaryMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        leadEPMName = Self.nonempty(draft.leadEPMName)
        projectDRIName = Self.nonempty(draft.projectDRIName)
        assets = draft.assets
    }

    private static func nonempty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
