import Foundation

struct EngineeringMetric: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var currentValue: Double
    var target: MetricTarget?
    var unit: String?
    var severity: MetricSeverity?
}

extension EngineeringMetric {
    var deltaFromTarget: Double? {
        guard let target else { return nil }
        return currentValue - target.value
    }

    /// Evaluate the exact stored values, including strict comparison boundaries.
    var targetStatus: MetricTargetStatus {
        guard let target else { return .notSet }
        let met: Bool
        switch target.comparison {
        case .lessThan: met = currentValue < target.value
        case .lessThanOrEqual: met = currentValue <= target.value
        case .greaterThan: met = currentValue > target.value
        case .greaterThanOrEqual: met = currentValue >= target.value
        case .equal: met = currentValue == target.value
        }
        return met ? .met : .missed
    }
}
