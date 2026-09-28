import Foundation

nonisolated enum CompositionEditError: Error {
    case invalidProposal
    case conflictingEdits
}

/// Build an independent candidate once so new metric IDs remain stable during selection.
nonisolated struct CompositionEdits {
    let base: ReportEditorDraft
    let proposed: ReportEditorDraft
    let fields: Set<CompositionTextChange.Field>
    let metricIDs: Set<UUID>

    init(base: ReportEditorDraft, proposal: CompositionProposal) throws {
        var draft = base
        var fields = Set<CompositionTextChange.Field>()
        var metricIDs = Set<UUID>()
        guard proposal.proposedChanges.count <= CompositionTextChange.Field.allCases.count, proposal.metricChanges.count <= 100,
              Set(base.metrics.map(\.id)).count == base.metrics.count else {
            throw CompositionEditError.invalidProposal
        }
        for change in proposal.proposedChanges {
            guard fields.insert(change.field).inserted else { throw CompositionEditError.invalidProposal }
            try Self.apply(change, to: &draft)
        }
        for change in proposal.metricChanges {
            switch change.operation {
            case .add:
                guard change.id == nil, let values = change.values else { throw CompositionEditError.invalidProposal }
                let metric = try Self.metric(values, id: UUID())
                metricIDs.insert(metric.id)
                draft.metrics.append(metric)
            case .update, .remove:
                guard let id = change.id, metricIDs.insert(id).inserted,
                      let index = draft.metrics.firstIndex(where: { $0.id == id }) else {
                    throw CompositionEditError.invalidProposal
                }
                if change.operation == .remove {
                    guard change.values == nil else { throw CompositionEditError.invalidProposal }
                    draft.metrics.remove(at: index)
                } else {
                    guard let values = change.values else { throw CompositionEditError.invalidProposal }
                    draft.metrics[index] = try Self.metric(values, id: id)
                }
            }
        }
        guard draft.metrics.count <= 100 else { throw CompositionEditError.invalidProposal }
        self.base = base
        proposed = draft
        self.fields = fields
        self.metricIDs = metricIDs
    }

    /// Select changes without mutating the editor or rebuilding generated identities.
    func selecting(fields selectedFields: Set<CompositionTextChange.Field>, metrics selectedMetrics: Set<UUID>) -> ReportEditorDraft {
        var result = base
        for field in fields.intersection(selectedFields) { Self.copy(field, from: proposed, to: &result) }
        let orderedIDs = base.metrics.map(\.id) + proposed.metrics.map(\.id).filter { id in !base.metrics.contains { $0.id == id } }
        for id in orderedIDs where metricIDs.contains(id) && selectedMetrics.contains(id) {
            Self.copyMetric(id, from: proposed, to: &result)
        }
        return result
    }

    private static func apply(_ change: CompositionTextChange, to draft: inout ReportEditorDraft) throws {
        if change.operation == .clear {
            guard change.value == nil, change.field != .summaryType else { throw CompositionEditError.invalidProposal }
        } else {
            guard let value = change.value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  value.utf16.count <= (change.field == .summaryMessage ? 20_000 : 200) else {
                throw CompositionEditError.invalidProposal
            }
        }
        let value = change.value ?? ""
        switch change.field {
        case .codeName: draft.codeName = value
        case .lineOfBusiness: draft.lineOfBusiness = value
        case .milestonePhase: draft.milestonePhase = value
        case .summaryMessage: draft.summaryMessage = value
        case .leadEPMName: draft.leadEPMName = value
        case .projectDRIName: draft.projectDRIName = value
        case .projectSize:
            guard change.operation == .clear || ProjectSize(rawValue: value) != nil else { throw CompositionEditError.invalidProposal }
            draft.projectSize = ProjectSize(rawValue: value)
        case .ragStatus:
            guard change.operation == .clear || RAGStatus(rawValue: value) != nil else { throw CompositionEditError.invalidProposal }
            draft.ragStatus = RAGStatus(rawValue: value)
        case .summaryType:
            guard let type = SummaryType(rawValue: value) else { throw CompositionEditError.invalidProposal }
            draft.summaryType = type
        case .milestoneDeadline:
            if change.operation == .clear { draft.milestoneDeadline = nil; return }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.isLenient = false
            guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
                throw CompositionEditError.invalidProposal
            }
            draft.milestoneDeadline = date
        }
    }

    private static func metric(_ values: CompositionMetricChange.Values, id: UUID) throws -> EngineeringMetricDraft {
        guard !values.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              values.name.utf16.count <= 200, (values.unit ?? "").utf16.count <= 50,
              values.currentValue.isFinite, values.targetValue?.isFinite != false,
              (values.targetValue == nil) == (values.comparison == nil),
              values.comparison == nil || MetricComparison(rawValue: values.comparison ?? "") != nil,
              values.severity == nil || MetricSeverity(rawValue: values.severity ?? "") != nil else {
            throw CompositionEditError.invalidProposal
        }
        var result = EngineeringMetricDraft(id: id)
        result.name = values.name
        result.currentValueText = String(values.currentValue)
        result.hasTarget = values.targetValue != nil
        result.targetValueText = values.targetValue.map { String($0) } ?? ""
        result.comparison = values.comparison.flatMap(MetricComparison.init(rawValue:)) ?? .lessThan
        result.unit = values.unit ?? ""
        result.severity = values.severity.flatMap(MetricSeverity.init(rawValue:))
        return result
    }

    static func copy(_ field: CompositionTextChange.Field, from source: ReportEditorDraft, to target: inout ReportEditorDraft) {
        switch field {
        case .codeName: target.codeName = source.codeName
        case .lineOfBusiness: target.lineOfBusiness = source.lineOfBusiness
        case .projectSize: target.projectSize = source.projectSize
        case .ragStatus: target.ragStatus = source.ragStatus
        case .milestonePhase: target.milestonePhase = source.milestonePhase
        case .milestoneDeadline: target.milestoneDeadline = source.milestoneDeadline
        case .summaryType: target.summaryType = source.summaryType
        case .summaryMessage: target.summaryMessage = source.summaryMessage
        case .leadEPMName: target.leadEPMName = source.leadEPMName
        case .projectDRIName: target.projectDRIName = source.projectDRIName
        }
    }

    static func copyMetric(_ id: UUID, from source: ReportEditorDraft, to target: inout ReportEditorDraft) {
        let replacement = source.metrics.first { $0.id == id }
        if let index = target.metrics.firstIndex(where: { $0.id == id }) {
            if let replacement { target.metrics[index] = replacement }
            else { target.metrics.remove(at: index) }
        } else if let replacement, let index = source.metrics.firstIndex(where: { $0.id == id }) {
            target.metrics.insert(replacement, at: min(index, target.metrics.count))
        }
    }
}

/// Undo only fields changed by Apply; reject conflicting later edits atomically.
nonisolated struct CompositionUndo {
    let before: ReportEditorDraft
    let after: ReportEditorDraft

    func restoring(_ current: ReportEditorDraft) throws -> ReportEditorDraft {
        var result = current
        for field in CompositionTextChange.Field.allCases {
            var previous = after
            CompositionEdits.copy(field, from: before, to: &previous)
            guard previous != after else { continue }
            var check = current
            CompositionEdits.copy(field, from: after, to: &check)
            guard check == current else { throw CompositionEditError.conflictingEdits }
            CompositionEdits.copy(field, from: before, to: &result)
        }
        let ids = before.metrics.map(\.id) + after.metrics.map(\.id).filter { id in !before.metrics.contains { $0.id == id } }
        for id in ids {
            let previous = before.metrics.first { $0.id == id }
            let applied = after.metrics.first { $0.id == id }
            guard previous != applied else { continue }
            guard current.metrics.first(where: { $0.id == id }) == applied else {
                throw CompositionEditError.conflictingEdits
            }
            CompositionEdits.copyMetric(id, from: before, to: &result)
        }
        return result
    }
}
