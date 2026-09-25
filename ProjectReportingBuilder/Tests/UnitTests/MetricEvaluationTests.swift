import Foundation
import Testing
@testable import Project_Report_Builder

struct MetricEvaluationTests {
    @Test func everyComparisonHandlesBothSidesAndEquality() {
        let cases: [(MetricComparison, [MetricTargetStatus])] = [
            (.lessThan, [.met, .missed, .missed]),
            (.lessThanOrEqual, [.met, .met, .missed]),
            (.greaterThan, [.missed, .missed, .met]),
            (.greaterThanOrEqual, [.missed, .met, .met]),
            (.equal, [.missed, .met, .missed])
        ]
        for (comparison, expected) in cases {
            for (index, value) in [99.0, 100.0, 101.0].enumerated() {
                let metric = EngineeringMetric(id: UUID(), name: "Latency", currentValue: value,
                    target: MetricTarget(value: 100, comparison: comparison), unit: "ms", severity: nil)
                #expect(metric.targetStatus == expected[index])
                #expect(metric.deltaFromTarget == value - 100)
            }
        }
    }

    @Test func formattingDistinguishesDirectionFromSuccess() {
        var metric = EngineeringMetric(id: UUID(), name: "Success", currentValue: 98,
            target: MetricTarget(value: 95, comparison: .greaterThanOrEqual), unit: "%", severity: nil)
        #expect(MetricPresentation.target(metric) == "Target ≥ 95 %")
        #expect(MetricPresentation.comparison(metric) == "Target met · 3 % above target")
        metric.currentValue = 95
        metric.target?.comparison = .greaterThan
        #expect(MetricPresentation.comparison(metric) == "Target missed · Equal to target")
        metric.target = nil
        #expect(metric.targetStatus == .notSet)
        #expect(metric.deltaFromTarget == nil)
        #expect(MetricPresentation.comparison(metric) == "No target set")
        #expect(MetricPresentation.value(2, unit: " ") == "2")
        #expect(MetricPresentation.value(0.125, unit: nil) == "0.125")
    }
}
