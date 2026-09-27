import Foundation

/// Describe the user's intent without giving the model control of completion rules.
nonisolated struct ReportCompositionGoal: Codable, Equatable, Sendable {
    enum Audience: String, Codable, CaseIterable, Sendable {
        case leadership, engineering, stakeholders
    }

    enum Purpose: String, Codable, CaseIterable, Sendable {
        case statusUpdate, escalation, supportRequest
    }

    enum Language: String, Codable, CaseIterable, Sendable {
        case english, traditionalChinese, simplifiedChinese
    }

    enum Section: String, Codable, CaseIterable, Sendable {
        case summary, health, milestone, accountability, metrics
    }

    let id: UUID
    let revision: Int
    let criterionPolicyVersion: Int
    let audience: Audience
    let purpose: Purpose
    let language: Language
    let requiredSections: [Section]

    init(id: UUID = UUID(), revision: Int = 1, criterionPolicyVersion: Int = 1,
         audience: Audience = .leadership, purpose: Purpose = .statusUpdate,
         language: Language = .english, requiredSections: [Section] = [.summary]) {
        self.id = id
        self.revision = revision
        self.criterionPolicyVersion = criterionPolicyVersion
        self.audience = audience
        self.purpose = purpose
        self.language = language
        self.requiredSections = requiredSections
    }

    var isSupported: Bool {
        revision > 0 && criterionPolicyVersion == 1
            && Set(requiredSections).count == requiredSections.count
    }
}

/// Bind a request or confirmation to one account session and exact report snapshots.
nonisolated struct CompositionVersion: Equatable, Sendable {
    let accountSessionID: UUID
    let reportID: UUID
    let baseDraftVersion: UUID
    let goal: ReportCompositionGoal
    let candidateVersion: UUID
}

/// Record user review separately from applying or saving the report.
nonisolated struct GoalConfirmation: Equatable, Sendable {
    let version: CompositionVersion
    let reviewedCriteria: Set<GoalCriterion.ID>
}
