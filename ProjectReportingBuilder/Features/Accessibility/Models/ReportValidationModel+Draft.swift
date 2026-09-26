import Foundation

extension ReportValidationModel {
    init(draft: ReportEditorDraft) {
        let preview = ReportPreviewModel(draft: draft)
        let style = ReportAccessibilityStyle.canonical
        codeName = draft.codeName
        statusLabel = draft.ragStatus?.displayName
        // Preserve invalid metrics too: their missing names still need checking.
        metricNames = draft.metrics.map(\.name)
        metricStatusLabels = preview.metrics.compactMap { item in
            item.metric.map { ReportAccessibilityStyle.metricStatusLabel($0.targetStatus) }
        }
        assets = draft.assets
        visibleSections = [.identity]
        if preview.ragStatus != nil || preview.milestonePhase != nil || preview.milestoneDeadline != nil {
            visibleSections.append(.health)
        }
        if !draft.metrics.isEmpty { visibleSections.append(.metrics) }
        if !preview.summaryMessage.isEmpty { visibleSections.append(.summary) }
        if !draft.assets.isEmpty { visibleSections.append(.supportingContent) }
        roleLabels = []
        if preview.leadEPMName != nil { roleLabels.append(style.leadRole) }
        if preview.projectDRIName != nil { roleLabels.append(style.driRole) }
        if !roleLabels.isEmpty { visibleSections.append(.accountability) }
        func addDataIssue(_ message: String?, title: String, section: ReportSection) {
            guard let message else { return }
            dataIssues.append(ReportValidationIssue(id: UUID(), type: .invalidData, severity: .error,
                                                   title: title, message: message, section: section))
        }
        addDataIssue(draft.codeNameError, title: "Missing project title", section: .identity)
        addDataIssue(draft.lineOfBusinessError, title: "Invalid product line", section: .identity)
        addDataIssue(draft.milestoneError, title: "Incomplete milestone", section: .health)
        for (index, metric) in draft.metrics.enumerated() {
            addDataIssue(metric.validationError(in: draft.metrics),
                         title: "Metric \(index + 1): " + (metric.name.isEmpty ? "Unnamed" : metric.name),
                         section: .metrics)
        }
    }
}
