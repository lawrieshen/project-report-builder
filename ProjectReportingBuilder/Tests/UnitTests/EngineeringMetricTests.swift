import Foundation
import Testing
@testable import Project_Report_Builder

struct EngineeringMetricTests {
    private func card() -> SnippetCard {
        SnippetCard(id: UUID(), health: ProjectHealth(ragStatus: nil, milestone: nil),
                    summary: ExecutiveSummary(type: .update, message: ""),
                    accountability: Accountability(leadEPM: nil, projectDRI: nil))
    }

    @Test func metricsRoundTripWithOrderAndIdentity() throws {
        var card = card()
        card.metrics = [
            EngineeringMetric(id: UUID(), name: "Latency", currentValue: 120,
                              target: MetricTarget(value: 100, comparison: .lessThan), unit: "ms", severity: .p1),
            EngineeringMetric(id: UUID(), name: "Bugs", currentValue: 2,
                              target: nil, unit: nil, severity: nil)
        ]
        let decoded = try JSONDecoder().decode(SnippetCard.self, from: JSONEncoder().encode(card))
        #expect(decoded == card)
    }

    @Test func oldCardsWithoutMetricsDecodeAsEmpty() throws {
        let card = card()
        let encoded = try JSONEncoder().encode(card)
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "metrics")
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(SnippetCard.self, from: data)
        #expect(decoded == card)
        #expect(decoded.metrics.isEmpty)
        json["metrics"] = "invalid data"
        let invalid = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(SnippetCard.self, from: invalid) }
    }
}
