extension ReportPreviewModel {
    var summaryHeading: String {
        switch summaryType {
        case .update: return "Latest Update"
        case .blocker: return "Blocker"
        case .ask: return "Ask"
        }
    }
}
