import Foundation
import Testing
@testable import Project_Report_Builder

struct EngineeringMetricDraftTests {
    @Test func invalidNumbersRemainTextAndCannotConvert() {
        for value in ["", "-", "abc", "NaN", "inf", "-Infinity", "1e999", "1,5", "1,000", "0x1p2"] {
            var draft = EngineeringMetricDraft()
            draft.name = "Latency"
            draft.currentValueText = value
            #expect(draft.validationError() != nil)
            #expect(draft.currentValueText == value)
            #expect(throws: MetricValidationError.self) { try draft.makeMetric() }
        }
        #expect(EngineeringMetricDraft.number("12.") == 12)
        #expect(EngineeringMetricDraft.number(" -1.25e2 ") == -125)
    }

    @Test func duplicateNamesExcludeTheEditedMetric() {
        var first = EngineeringMetricDraft()
        first.name = " UI Latency "
        first.currentValueText = "120"
        var second = EngineeringMetricDraft()
        second.name = "ui latency"
        second.currentValueText = "100"
        #expect(first.validationError(in: [first]) == nil)
        #expect(second.validationError(in: [first]) != nil)
    }

    @Test func optionalTargetAndMappingPreserveAllValues() throws {
        var draft = EngineeringMetricDraft()
        draft.name = " Latency "
        draft.currentValueText = "120.5"
        draft.targetValueText = "invalid but disabled"
        #expect(try draft.makeMetric().target == nil)
        draft.hasTarget = true
        #expect(draft.validationError() != nil)
        draft.targetValueText = "100"
        draft.comparison = .lessThanOrEqual
        draft.unit = " ms "
        draft.severity = .p1
        let metric = try draft.makeMetric()
        #expect(metric.id == draft.id)
        #expect(metric.name == "Latency")
        #expect(metric.currentValue == 120.5)
        #expect(metric.target == MetricTarget(value: 100, comparison: .lessThanOrEqual))
        #expect(metric.unit == "ms")
        #expect(metric.severity == .p1)
        #expect(try EngineeringMetricDraft(metric: metric).makeMetric() == metric)
    }

    @Test func reportMappingPreservesOrderAndRejectsInvalidMetrics() throws {
        let metrics = ["One", "Two"].map {
            EngineeringMetric(id: UUID(), name: $0, currentValue: 1, target: nil, unit: nil, severity: nil)
        }
        var project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone",
                                    status: .active, createdAt: .now, updatedAt: .now)
        project.card = SnippetCard(id: UUID(), health: ProjectHealth(ragStatus: nil, milestone: nil),
            summary: ExecutiveSummary(type: .update, message: ""),
            accountability: Accountability(leadEPM: nil, projectDRI: nil), metrics: metrics)
        var draft = ReportEditorDraft(project: project)
        let saved = try draft.applying(to: project, cardID: UUID(), updatedAt: .now)
        #expect(saved.card?.metrics == metrics)
        draft.metrics[1].currentValueText = "bad"
        #expect(!draft.isValid)
        #expect(throws: MetricValidationError.self) {
            try draft.applying(to: project, cardID: UUID(), updatedAt: .now)
        }
    }
}
