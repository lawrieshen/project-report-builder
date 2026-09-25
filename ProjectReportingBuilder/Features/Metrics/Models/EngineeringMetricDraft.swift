import Foundation

/// Preserve partially typed numbers until the user confirms a metric.
nonisolated struct EngineeringMetricDraft: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name = ""
    var currentValueText = ""
    var hasTarget = false
    var targetValueText = ""
    var comparison: MetricComparison = .lessThan
    var unit = ""
    var severity: MetricSeverity?

    init(id: UUID = UUID()) { self.id = id }

    init(metric: EngineeringMetric) {
        id = metric.id
        name = metric.name
        currentValueText = String(metric.currentValue)
        hasTarget = metric.target != nil
        targetValueText = metric.target.map { String($0.value) } ?? ""
        comparison = metric.target?.comparison ?? .lessThan
        unit = metric.unit ?? ""
        severity = metric.severity
    }

    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func validationError(in metrics: [EngineeringMetricDraft] = []) -> String? {
        if normalizedName.isEmpty { return "Enter a metric name." }
        if metrics.contains(where: { $0.id != id && $0.normalizedName == normalizedName }) {
            return "Metric names must be unique in this report."
        }
        if Self.number(currentValueText) == nil { return "Enter a finite current value using a decimal point." }
        if hasTarget && Self.number(targetValueText) == nil {
            return "Enter a finite target value using a decimal point."
        }
        return nil
    }

    /// Parse finite decimal values; grouping separators and ambiguous formats are rejected.
    static func number(_ text: String) -> Double? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"#
        guard text.range(of: pattern, options: .regularExpression) != nil,
              let value = Double(text), value.isFinite else { return nil }
        return value
    }

    /// Convert valid input without silently dropping invalid metrics.
    /// - Throws: A validation error when required fields or numbers are invalid.
    func makeMetric() throws -> EngineeringMetric {
        if let message = validationError() { throw MetricValidationError(message: message) }
        guard let current = Self.number(currentValueText) else {
            throw MetricValidationError(message: "Enter a valid current value.")
        }
        var target: MetricTarget?
        if hasTarget {
            guard let value = Self.number(targetValueText) else {
                throw MetricValidationError(message: "Enter a valid target value.")
            }
            target = MetricTarget(value: value, comparison: comparison)
        }
        let unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return EngineeringMetric(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                 currentValue: current, target: target, unit: unit.isEmpty ? nil : unit,
                                 severity: severity)
    }
}

nonisolated struct MetricValidationError: LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
}
