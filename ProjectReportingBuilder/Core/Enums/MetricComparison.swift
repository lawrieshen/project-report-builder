nonisolated enum MetricComparison: String, Codable, CaseIterable, Sendable {
    case lessThan
    case lessThanOrEqual
    case greaterThan
    case greaterThanOrEqual
    case equal
}
