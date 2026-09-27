import Foundation

/// Explain one deterministic requirement or one decision that needs human review.
nonisolated struct GoalCriterion: Identifiable, Equatable, Sendable {
    enum ID: String, Codable, CaseIterable, Sendable {
        case supportedGoal, validDraft, summary, health, milestone, accountability, metrics
        case audienceFit, languageFit, factualAccuracy, clearAsk, clearBlocker
    }

    enum Status: Sendable { case missing, needsReview, satisfied }
    enum Evidence: Sendable { case rule, modelSuggestion, userConfirmation }

    let id: ID
    var status: Status
    let explanation: String
    var evidence: Evidence
}

nonisolated struct GoalEvaluation: Equatable, Sendable {
    let version: CompositionVersion
    let criteria: [GoalCriterion]

    var readyForReview: Bool { !criteria.contains { $0.status == .missing } }
    var isConfirmed: Bool { criteria.allSatisfy { $0.status == .satisfied } }
}

/// Evaluate a candidate locally; model findings never satisfy human review criteria.
nonisolated enum GoalEvaluator {
    static func evaluate(draft: ReportEditorDraft, version: CompositionVersion,
                         findings: [CompositionFinding] = [],
                         confirmation: GoalConfirmation? = nil) -> GoalEvaluation {
        let goal = version.goal
        var criteria: [GoalCriterion] = []
        func rule(_ id: GoalCriterion.ID, _ passes: Bool, _ explanation: String) {
            criteria.append(GoalCriterion(id: id, status: passes ? .satisfied : .missing,
                                          explanation: explanation, evidence: .rule))
        }
        rule(.supportedGoal, goal.isSupported, "Use supported goal options and policy version.")
        rule(.validDraft, draft.isValid, "Resolve report field validation before confirming.")
        for section in Set(goal.requiredSections).sorted(by: { $0.rawValue < $1.rawValue }) {
            switch section {
            case .summary: rule(.summary, hasText(draft.summaryMessage), "Include an executive summary.")
            case .health: rule(.health, draft.ragStatus != nil, "Choose a health status.")
            case .milestone:
                rule(.milestone, hasText(draft.milestonePhase) && draft.milestoneDeadline != nil
                     && draft.milestoneError == nil, "Include a valid milestone phase and deadline.")
            case .accountability:
                rule(.accountability, hasText(draft.leadEPMName) && hasText(draft.projectDRIName),
                     "Name the lead EPM and project DRI.")
            case .metrics:
                rule(.metrics, !draft.metrics.isEmpty && draft.metricsError == nil, "Include valid engineering metrics.")
            }
        }

        var review: [(GoalCriterion.ID, String)] = [
            (.audienceFit, "Review whether the report fits the selected audience."),
            (.languageFit, "Review whether the report uses the selected language."),
            (.factualAccuracy, "Check facts, numbers, units, and unsupported assumptions.")
        ]
        switch goal.purpose {
        case .statusUpdate: break
        case .escalation: review.append((.clearBlocker, "Confirm the summary clearly explains the blocker and impact."))
        case .supportRequest: review.append((.clearAsk, "Confirm the summary makes a clear support request."))
        }
        let accepted = confirmation?.version == version ? confirmation?.reviewedCriteria ?? [] : []
        for (id, explanation) in review {
            let finding = findings.first { $0.criterionID == id }
            criteria.append(GoalCriterion(id: id, status: accepted.contains(id) ? .satisfied : .needsReview,
                explanation: finding?.explanation ?? explanation,
                evidence: accepted.contains(id) ? .userConfirmation : finding == nil ? .rule : .modelSuggestion))
        }
        return GoalEvaluation(version: version, criteria: criteria)
    }

    private static func hasText(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
