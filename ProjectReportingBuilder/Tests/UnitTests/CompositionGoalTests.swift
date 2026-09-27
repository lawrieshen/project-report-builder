import Foundation
import Testing
@testable import Project_Report_Builder

struct CompositionGoalTests {
    private func draft() -> ReportEditorDraft {
        ReportEditorDraft(project: ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Mac",
            status: .draft, createdAt: .now, updatedAt: .now))
    }

    private func version(goal: ReportCompositionGoal = ReportCompositionGoal()) -> CompositionVersion {
        CompositionVersion(accountSessionID: UUID(), reportID: UUID(), baseDraftVersion: UUID(),
                           goal: goal, candidateVersion: UUID())
    }

    @Test func missingSummaryAndModelPraiseCannotCompleteGoal() {
        let version = version()
        let missing = GoalEvaluator.evaluate(draft: draft(), version: version)
        #expect(!missing.readyForReview)
        var candidate = draft()
        candidate.summaryMessage = "Validation is in progress."
        let evaluation = GoalEvaluator.evaluate(draft: candidate, version: version,
            assessment: CompositionAssessment(version: version, findings: [
            CompositionFinding(criterionID: .factualAccuracy, explanation: "Everything looks correct.")
        ]))
        #expect(evaluation.readyForReview)
        #expect(!evaluation.isConfirmed)
        #expect(evaluation.criteria.first { $0.id == .factualAccuracy }?.status == .needsReview)
    }

    @Test func confirmationRequiresExactVersionAndEveryReviewCriterion() {
        var candidate = draft()
        candidate.summaryMessage = "Need a decision on the schedule."
        let version = version(goal: ReportCompositionGoal(purpose: .supportRequest))
        let confirmation = GoalConfirmation(version: version,
            reviewedCriteria: [.audienceFit, .languageFit, .factualAccuracy, .clearAsk])
        #expect(GoalEvaluator.evaluate(draft: candidate, version: version, confirmation: confirmation).isConfirmed)
        let changed = CompositionVersion(accountSessionID: version.accountSessionID, reportID: version.reportID,
            baseDraftVersion: version.baseDraftVersion, goal: version.goal, candidateVersion: UUID())
        #expect(!GoalEvaluator.evaluate(draft: candidate, version: changed, confirmation: confirmation).isConfirmed)
        candidate.summaryMessage = ""
        #expect(!GoalEvaluator.evaluate(draft: candidate, version: changed, confirmation: confirmation).readyForReview)
    }

    @Test func requiredSectionsReuseDraftValidation() {
        var candidate = draft()
        let goal = ReportCompositionGoal(requiredSections: [.milestone, .accountability, .metrics, .health])
        let version = version(goal: goal)
        candidate.milestonePhase = "DVT"
        #expect(!GoalEvaluator.evaluate(draft: candidate, version: version).readyForReview)
        candidate.milestoneDeadline = .now
        candidate.ragStatus = .amber
        candidate.leadEPMName = "Sam"
        candidate.projectDRIName = "Alex"
        var metric = EngineeringMetricDraft()
        metric.name = "Bugs"
        metric.currentValueText = "3"
        candidate.metrics = [metric]
        #expect(GoalEvaluator.evaluate(draft: candidate, version: version).readyForReview)
        candidate.metrics[0].currentValueText = "unknown"
        #expect(!GoalEvaluator.evaluate(draft: candidate, version: version).readyForReview)
    }

    @Test func unsupportedPolicyCannotBeConfirmed() {
        let version = version(goal: ReportCompositionGoal(criterionPolicyVersion: 99))
        #expect(!GoalEvaluator.evaluate(draft: draft(), version: version).readyForReview)
    }

    @Test func findingsFromAnOlderCandidateAreDiscarded() {
        let oldVersion = version()
        let assessment = CompositionAssessment(version: oldVersion, findings: [
            CompositionFinding(criterionID: .factualAccuracy, explanation: "Old assessment")
        ])
        let updated = CompositionVersion(accountSessionID: oldVersion.accountSessionID, reportID: oldVersion.reportID,
            baseDraftVersion: oldVersion.baseDraftVersion, goal: oldVersion.goal, candidateVersion: UUID())
        let result = GoalEvaluator.evaluate(draft: draft(), version: updated, assessment: assessment)
        #expect(result.criteria.first { $0.id == .factualAccuracy }?.evidence == .rule)
    }
}
