import Foundation
import Testing
@testable import Project_Report_Builder

struct CompositionEditsTests {
    private func draft() -> ReportEditorDraft {
        ReportEditorDraft(project: ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Mac",
            status: .active, createdAt: .now, updatedAt: .now))
    }

    private func proposal(_ changes: [CompositionTextChange] = [], metrics: [CompositionMetricChange] = []) -> CompositionProposal {
        CompositionProposal(assistantMessage: "Review these changes", clarifyingQuestions: [],
            proposedChanges: changes, metricChanges: metrics, warnings: [], semanticFindings: [])
    }

    @Test func partialSelectionPreservesSourceAndImages() throws {
        var base = draft()
        base.assets = [ImageAsset(id: UUID(), fileName: "photo.png", localReference: "/private/photo.png")]
        let edits = try CompositionEdits(base: base, proposal: proposal([
            .init(field: .summaryMessage, operation: .set, value: "Revised"),
            .init(field: .codeName, operation: .set, value: "New name")]))
        let selected = edits.selecting(fields: [.summaryMessage], metrics: [])
        #expect(selected.summaryMessage == "Revised")
        #expect(selected.codeName == base.codeName)
        #expect(selected.assets == base.assets)
        #expect(base.summaryMessage.isEmpty)
    }

    @Test func invalidFieldsAndDatesRejectEntireProposal() throws {
        for change in [CompositionTextChange(field: .summaryType, operation: .clear, value: nil),
            .init(field: .ragStatus, operation: .set, value: "purple"),
            .init(field: .milestoneDeadline, operation: .set, value: "2026-02-30"),
            .init(field: .summaryMessage, operation: .clear, value: "ignored")] {
            #expect(throws: CompositionEditError.self) { try CompositionEdits(base: draft(), proposal: proposal([change])) }
        }
        let change = CompositionTextChange(field: .summaryMessage, operation: .set, value: "Updated")
        #expect(throws: CompositionEditError.self) { try CompositionEdits(base: draft(), proposal: proposal([change, change])) }
    }

    @Test func metricIDsAndOrderRemainStableAcrossSelection() throws {
        let changes = ["First", "Second", "Third"].map { name in
            CompositionMetricChange(operation: .add, id: nil, values: .init(name: name,
                currentValue: 2.5, targetValue: nil, comparison: nil, unit: "ms", severity: nil))
        }
        let edits = try CompositionEdits(base: draft(), proposal: proposal(metrics: changes))
        let full = edits.selecting(fields: [], metrics: edits.metricIDs)
        #expect(full.metrics.map(\.name) == ["First", "Second", "Third"])
        #expect(edits.selecting(fields: [], metrics: edits.metricIDs) == full)
        #expect(edits.selecting(fields: [], metrics: []).metrics.isEmpty)
        #expect(throws: CompositionEditError.self) {
            try CompositionEdits(base: draft(), proposal: proposal(metrics: [.init(operation: .remove, id: UUID(), values: nil)]))
        }
    }

    @Test func undoPreservesLaterUnrelatedEditsAndImages() throws {
        let before = draft()
        var after = before
        after.summaryMessage = "AI summary"
        var current = after
        current.codeName = "Manual name"
        current.assets = [ImageAsset(id: UUID(), fileName: "later.png", localReference: "later.png")]
        let restored = try CompositionUndo(before: before, after: after).restoring(current)
        #expect(restored.summaryMessage == before.summaryMessage)
        #expect(restored.codeName == current.codeName)
        #expect(restored.assets == current.assets)
        current.summaryMessage = "Manual summary"
        #expect(throws: CompositionEditError.self) { try CompositionUndo(before: before, after: after).restoring(current) }
        #expect(current.summaryMessage == "Manual summary")
    }

    @Test func undoRestoresRemovedMetricOrderAndPreservesNewMetrics() throws {
        var before = draft()
        before.metrics = (0..<3).map { index in
            var metric = EngineeringMetricDraft()
            metric.name = "Original \(index)"
            return metric
        }
        var after = before
        after.metrics.removeAll()
        var current = after
        let later = EngineeringMetricDraft()
        current.metrics = [later]
        let restored = try CompositionUndo(before: before, after: after).restoring(current)
        #expect(restored.metrics.map(\.id) == before.metrics.map(\.id) + [later.id])
    }
}
