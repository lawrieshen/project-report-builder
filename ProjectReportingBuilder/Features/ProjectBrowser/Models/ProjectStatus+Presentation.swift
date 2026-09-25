extension ProjectStatus {
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .active: return "Active"
        case .archived: return "Archived"
        }
    }
}
