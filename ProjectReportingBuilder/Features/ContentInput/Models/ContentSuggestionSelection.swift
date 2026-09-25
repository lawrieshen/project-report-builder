import Foundation

enum ContentSuggestionField: String, CaseIterable, Identifiable {
    case codeName, lineOfBusiness, health, milestone, deadline
    case summaryType, summary, leadEPM, projectDRI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codeName: return "Project Code Name"
        case .lineOfBusiness: return "Line of Business"
        case .health: return "Health"
        case .milestone: return "Milestone Phase"
        case .deadline: return "Milestone Deadline"
        case .summaryType: return "Summary Type"
        case .summary: return "Executive Summary"
        case .leadEPM: return "Lead EPM"
        case .projectDRI: return "Project DRI"
        }
    }

    func suggestedValue(in suggestions: ReportContentSuggestions) -> String? {
        switch self {
        case .codeName: return suggestions.codeName
        case .lineOfBusiness: return suggestions.lineOfBusiness
        case .health: return suggestions.ragStatus?.rawValue.capitalized
        case .milestone: return suggestions.milestonePhase
        case .deadline: return suggestions.milestoneDeadline?.formatted(date: .numeric, time: .omitted)
        case .summaryType: return suggestions.summaryType?.rawValue.capitalized
        case .summary: return suggestions.summaryMessage
        case .leadEPM: return suggestions.leadEPMName
        case .projectDRI: return suggestions.projectDRIName
        }
    }

    func currentValue(in draft: ReportEditorDraft) -> String {
        switch self {
        case .codeName: return draft.codeName
        case .lineOfBusiness: return draft.lineOfBusiness
        case .health: return draft.ragStatus?.rawValue.capitalized ?? ""
        case .milestone: return draft.milestonePhase
        case .deadline: return draft.milestoneDeadline?.formatted(date: .numeric, time: .omitted) ?? ""
        case .summaryType: return draft.summaryType.rawValue.capitalized
        case .summary: return draft.summaryMessage
        case .leadEPM: return draft.leadEPMName
        case .projectDRI: return draft.projectDRIName
        }
    }
}

/// Preselect only empty fields; replacing an existing value needs an explicit choice.
struct ContentSuggestionSelection {
    var fields: Set<ContentSuggestionField> = []

    init() {}

    init(suggestions: ReportContentSuggestions, draft: ReportEditorDraft) {
        fields = Set(ContentSuggestionField.allCases.filter {
            $0.suggestedValue(in: suggestions) != nil
            && $0.currentValue(in: draft).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })
    }
}
