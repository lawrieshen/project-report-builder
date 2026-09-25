import Foundation

/// Parse explicit label/value notes; never infer facts from unstructured prose.
struct ContentProcessor: ContentProcessing {
    func process(text: String) async throws -> ReportContentSuggestions {
        var result = ReportContentSuggestions()
        let dateParser = DateFormatter()
        dateParser.locale = Locale(identifier: "en_US_POSIX")
        dateParser.timeZone = TimeZone(secondsFromGMT: 0)
        dateParser.dateFormat = "yyyy-MM-dd"
        dateParser.isLenient = false
        for line in text.components(separatedBy: .newlines) {
            try Task.checkCancellation()
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }
            switch key {
            case "project", "code name": result.codeName = value
            case "line of business": result.lineOfBusiness = value
            case "health", "rag": result.ragStatus = RAGStatus(rawValue: value.lowercased())
            case "milestone": result.milestonePhase = value
            case "deadline":
                if value.count == 10, let date = dateParser.date(from: value),
                   dateParser.string(from: date) == value { result.milestoneDeadline = date }
            case "summary type": result.summaryType = SummaryType(rawValue: value.lowercased())
            case "summary": result.summaryMessage = value
            case "lead epm": result.leadEPMName = value
            case "project dri": result.projectDRIName = value
            default: continue
            }
        }
        return result
    }
}
