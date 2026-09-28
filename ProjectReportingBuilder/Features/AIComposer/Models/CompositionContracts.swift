import Foundation

/// Send editable text only; omit report ownership, lifecycle status, and all image references.
nonisolated struct CompositionDraft: Codable, Equatable, Sendable {
    let codeName: String
    let lineOfBusiness: String
    let projectSize: ProjectSize?
    let ragStatus: RAGStatus?
    let milestonePhase: String
    let milestoneDeadline: String?
    let summaryType: SummaryType
    let summaryMessage: String
    let leadEPMName: String
    let projectDRIName: String
    let metrics: [EngineeringMetricDraft]

    init(draft: ReportEditorDraft) {
        codeName = draft.codeName
        lineOfBusiness = draft.lineOfBusiness
        projectSize = draft.projectSize
        ragStatus = draft.ragStatus
        milestonePhase = draft.milestonePhase
        milestoneDeadline = draft.milestoneDeadline.map {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: $0)
        }
        summaryType = draft.summaryType
        summaryMessage = draft.summaryMessage
        leadEPMName = draft.leadEPMName
        projectDRIName = draft.projectDRIName
        metrics = draft.metrics
    }
}

extension CompositionDraft {
    enum CodingKeys: String, CodingKey {
        case codeName, lineOfBusiness, projectSize, ragStatus, milestonePhase, milestoneDeadline
        case summaryType, summaryMessage, leadEPMName, projectDRIName, metrics
    }

    /// Include an unset size so the backend can distinguish this client from older versions.
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(codeName, forKey: .codeName)
        try values.encode(lineOfBusiness, forKey: .lineOfBusiness)
        try values.encode(projectSize, forKey: .projectSize)
        try values.encodeIfPresent(ragStatus, forKey: .ragStatus)
        try values.encode(milestonePhase, forKey: .milestonePhase)
        try values.encodeIfPresent(milestoneDeadline, forKey: .milestoneDeadline)
        try values.encode(summaryType, forKey: .summaryType)
        try values.encode(summaryMessage, forKey: .summaryMessage)
        try values.encode(leadEPMName, forKey: .leadEPMName)
        try values.encode(projectDRIName, forKey: .projectDRIName)
        try values.encode(metrics, forKey: .metrics)
    }
}

nonisolated struct CompositionMessage: Codable, Equatable, Sendable {
    enum Role: String, Codable, Sendable { case user, assistant }
    let role: Role
    let text: String
}

nonisolated struct CompositionRequest: Codable, Equatable, Sendable {
    let requestID: UUID
    let baseDraftVersion: UUID
    let candidateVersion: UUID
    let goal: ReportCompositionGoal
    let draft: CompositionDraft
    let messages: [CompositionMessage]
}

/// Represent explicit set/clear intent; absence from the list means unchanged.
nonisolated struct CompositionTextChange: Codable, Equatable, Sendable {
    enum Field: String, Codable, CaseIterable, Sendable {
        case codeName, lineOfBusiness, projectSize, ragStatus, milestonePhase, milestoneDeadline
        case summaryType, summaryMessage, leadEPMName, projectDRIName
    }
    enum Operation: String, Codable, Sendable { case set, clear }
    let field: Field
    let operation: Operation
    let value: String?
}

/// Assign new metric IDs locally; updates/removals must reference the submitted draft.
nonisolated struct CompositionMetricChange: Codable, Equatable, Sendable {
    enum Operation: String, Codable, Sendable { case add, update, remove }
    struct Values: Codable, Equatable, Sendable {
        let name: String
        let currentValue: Double
        let targetValue: Double?
        let comparison: String?
        let unit: String?
        let severity: String?
    }
    let operation: Operation
    let id: UUID?
    let values: Values?
}

nonisolated struct CompositionFinding: Codable, Equatable, Sendable {
    let criterionID: GoalCriterion.ID
    let explanation: String
}

nonisolated struct CompositionProposal: Codable, Equatable, Sendable {
    let assistantMessage: String
    let clarifyingQuestions: [String]
    let proposedChanges: [CompositionTextChange]
    let metricChanges: [CompositionMetricChange]
    let warnings: [String]
    let semanticFindings: [CompositionFinding]
}

nonisolated struct CompositionResponse: Codable, Equatable, Sendable {
    let requestID: UUID
    let baseDraftVersion: UUID
    let candidateVersion: UUID
    let goalID: UUID
    let goalRevision: Int
    let proposal: CompositionProposal
    let remainingDailyRequests: Int

    /// Match the backend's approved maximum without trusting arbitrary response counts.
    static let maximumDailyRequests = 100

    func matches(_ request: CompositionRequest) -> Bool {
        requestID == request.requestID && baseDraftVersion == request.baseDraftVersion
            && candidateVersion == request.candidateVersion && goalID == request.goal.id
            && goalRevision == request.goal.revision
    }
}

nonisolated enum CompositionErrorCode: String, Codable, Sendable {
    case disabled = "AI_DISABLED"
    case invalidInput = "INVALID_INPUT"
    case dailyQuota = "DAILY_QUOTA"
    case budgetExhausted = "BUDGET_EXHAUSTED"
    case requestPending = "REQUEST_PENDING"
    case requestMismatch = "REQUEST_MISMATCH"
    case requestExpired = "REQUEST_EXPIRED"
    case rateLimited = "PROVIDER_RATE_LIMITED"
    case timeout = "PROVIDER_TIMEOUT"
    case invalidOutput = "INVALID_OUTPUT"
    case unavailable = "AI_UNAVAILABLE"
}
