extension RAGStatus {
    var displayName: String {
        switch self {
        case .green: return "On Track"
        case .amber: return "At Risk"
        case .red: return "Off Track"
        }
    }

}
