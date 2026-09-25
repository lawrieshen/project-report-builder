/// Identify a workspace section independently of its view hierarchy.
enum ReportSection: String, CaseIterable, Identifiable {
    case identity, health, metrics, summary, accountability, supportingContent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .identity: return "Identity"
        case .health: return "Health"
        case .metrics: return "Engineering Metrics"
        case .summary: return "Summary"
        case .accountability: return "Accountability"
        case .supportingContent: return "Supporting Assets"
        }
    }
}
