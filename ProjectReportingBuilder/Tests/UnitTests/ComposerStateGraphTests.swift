import Foundation
import Testing
@testable import Project_Report_Builder

struct ComposerStateGraphTests {
    private func version() -> CompositionVersion {
        CompositionVersion(accountSessionID: UUID(), reportID: UUID(), baseDraftVersion: UUID(),
            goal: ReportCompositionGoal(), candidateVersion: UUID())
    }

    @Test func oneSendAndNoLateResponseAfterCancellation() {
        let version = version()
        var graph = ComposerStateGraph(version: version)
        let id = UUID()
        let sent = graph.send(.send(requestID: id, version: version))
        #expect(sent)
        let rejectedSecondSend = !graph.send(.send(requestID: UUID(), version: version))
        #expect(rejectedSecondSend)
        let cancelled = graph.send(.cancel)
        #expect(cancelled)
        let rejectedLateResponse = !graph.send(.received(requestID: id, version: version, candidateVersion: UUID()))
        #expect(rejectedLateResponse)
        #expect(graph.version == version)
        #expect(graph.state == .ready)
    }

    @Test func draftChangesAndClosingInvalidatePendingWork() {
        for invalidation in [ComposerEvent.baseChanged, .close] {
            let version = version()
            var graph = ComposerStateGraph(version: version)
            let id = UUID()
            graph.send(.send(requestID: id, version: version))
            let invalidated = graph.send(invalidation)
            #expect(invalidated)
            let rejectedObsoleteResponse = !graph.send(.received(requestID: id, version: version, candidateVersion: UUID()))
            #expect(rejectedObsoleteResponse)
            let rejectedApply = !graph.send(.apply(version: version, editorAllowsApply: true, acceptUnfinishedGoal: true))
            #expect(rejectedApply)
        }
    }

    @Test func failuresPreserveVersionAndRequireExplicitRetry() {
        let version = version()
        for limited in [false, true] {
            var graph = ComposerStateGraph(version: version)
            let id = UUID()
            graph.send(.send(requestID: id, version: version))
            let rejectedUnrelatedFailure = !graph.send(.failure(requestID: UUID(), limited: limited))
            #expect(rejectedUnrelatedFailure)
            let recordedFailure = graph.send(.failure(requestID: id, limited: limited))
            #expect(recordedFailure)
            #expect(graph.version == version)
            #expect(graph.state == (limited ? .limited : .failed))
            let retried = graph.send(.send(requestID: UUID(), version: version))
            #expect(retried)
        }
    }

    @Test func applyRequiresReviewAndEditorPermission() {
        let version = version()
        var graph = ComposerStateGraph(version: version)
        let rejectedUnreviewedApply = !graph.send(.apply(version: version, editorAllowsApply: true, acceptUnfinishedGoal: true))
        #expect(rejectedUnreviewedApply)
        let id = UUID()
        graph.send(.send(requestID: id, version: version))
        graph.send(.received(requestID: id, version: version, candidateVersion: UUID()))
        #expect(graph.state == .evaluating)
        graph.send(.evaluated(hasQuestions: false))
        let rejectedBusyEditor = !graph.send(.apply(version: graph.version, editorAllowsApply: false, acceptUnfinishedGoal: true))
        #expect(rejectedBusyEditor)
        let rejectedUnconfirmedApply = !graph.send(.apply(version: graph.version, editorAllowsApply: true, acceptUnfinishedGoal: false))
        #expect(rejectedUnconfirmedApply)
        let appliedUnfinishedEdits = graph.send(.apply(version: graph.version, editorAllowsApply: true, acceptUnfinishedGoal: true))
        #expect(appliedUnfinishedEdits)
        #expect(graph.confirmation == nil)
    }

    @Test func newAccountCannotRebaseOldCandidate() {
        var graph = ComposerStateGraph(version: version())
        graph.send(.baseChanged)
        let rejectedOtherAccount = !graph.send(.rebase(version()))
        #expect(rejectedOtherAccount)
        graph.send(.close)
        let rejectedClosedEvent = !graph.send(.baseChanged)
        #expect(rejectedClosedEvent)
    }

    @Test func exactUserConfirmationIsInvalidatedByCandidateEdits() {
        let initial = version()
        var graph = ComposerStateGraph(version: initial)
        let id = UUID()
        graph.send(.send(requestID: id, version: initial))
        graph.send(.received(requestID: id, version: initial, candidateVersion: UUID()))
        graph.send(.evaluated(hasQuestions: false))
        var draft = ReportEditorDraft(project: ProjectReport(id: initial.reportID, codeName: "Titan", lineOfBusiness: "Mac",
            status: .draft, createdAt: .now, updatedAt: .now))
        draft.summaryMessage = "Validation is in progress."
        let confirmation = GoalConfirmation(version: graph.version,
            reviewedCriteria: [.audienceFit, .languageFit, .factualAccuracy])
        let evaluation = GoalEvaluator.evaluate(draft: draft, version: graph.version, confirmation: confirmation)
        let confirmed = graph.send(.confirm(evaluation, confirmation))
        #expect(confirmed)
        #expect(graph.state == .confirmed)
        let updated = CompositionVersion(accountSessionID: initial.accountSessionID, reportID: initial.reportID,
            baseDraftVersion: initial.baseDraftVersion, goal: initial.goal, candidateVersion: UUID())
        graph.send(.candidateChanged(updated))
        graph.send(.evaluated(hasQuestions: false))
        let acceptedOldConfirmation = graph.send(.confirm(evaluation, confirmation))
        #expect(!acceptedOldConfirmation)
        #expect(graph.confirmation == nil)
    }
}
