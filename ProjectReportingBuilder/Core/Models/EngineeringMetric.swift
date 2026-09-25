import Foundation

struct EngineeringMetric: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var currentValue: Double
    var target: MetricTarget?
    var unit: String?
    var severity: MetricSeverity?
}
