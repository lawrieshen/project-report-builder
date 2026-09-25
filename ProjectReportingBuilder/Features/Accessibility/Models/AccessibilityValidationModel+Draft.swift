import Foundation

extension AccessibilityValidationModel {
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
    }
}
