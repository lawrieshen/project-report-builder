nonisolated struct MetricTarget: Codable, Equatable, Sendable {
    var value: Double
    var comparison: MetricComparison
}
