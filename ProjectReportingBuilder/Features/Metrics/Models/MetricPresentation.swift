import Foundation

extension MetricComparison {
    var symbol: String {
        switch self {
        case .lessThan: return "<"
        case .lessThanOrEqual: return "≤"
        case .greaterThan: return ">"
        case .greaterThanOrEqual: return "≥"
        case .equal: return "="
        }
    }
}

extension MetricSeverity {
    var displayName: String { rawValue.uppercased() }
}

/// Format metric values without persisting derived display text.
enum MetricPresentation {
    static func value(_ number: Double, unit: String?) -> String {
        let unit = unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // String preserves precision and uses the same decimal syntax as the editor.
        var text = String(number)
        if text.hasSuffix(".0") { text.removeLast(2) }
        return unit.isEmpty ? text : text + " " + unit
    }

    static func target(_ metric: EngineeringMetric) -> String {
        guard let target = metric.target else { return "No target" }
        return "Target " + target.comparison.symbol + " " + value(target.value, unit: metric.unit)
    }

    static func comparison(_ metric: EngineeringMetric) -> String {
        guard let delta = metric.deltaFromTarget else { return "No target set" }
        let status = metric.targetStatus == .met ? "Target met" : "Target missed"
        if delta == 0 { return status + " · Equal to target" }
        guard delta.isFinite else { return status }
        let direction = delta > 0 ? " above target" : " below target"
        return status + " · " + value(abs(delta), unit: metric.unit) + direction
    }
}
