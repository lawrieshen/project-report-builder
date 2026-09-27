import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct ReportComposerViewModelTests {
    private func make(_ service: FakeComposer) -> ReportComposerViewModel {
        let report = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Mac", status: .active,
                                   createdAt: .now, updatedAt: .now)
        return ReportComposerViewModel(draft: ReportEditorDraft(project: report), reportID: report.id,
                                       accountSessionID: UUID(), service: service)
    }

    @Test func multiTurnStaysSeparateUntilApplyAndUndoPreservesLaterEdits() async throws {
        let service = FakeComposer()
        let model = make(service)
        let original = model.base
        await model.send("Write a summary")
        #expect(model.candidate.summaryMessage == "Candidate 1")
        #expect(model.base == original)
        await model.send("Revise it")
        #expect(service.requests[1].draft.summaryMessage == "Candidate 1")
        #expect(model.candidate.summaryMessage == "Candidate 2")
        let version = model.graph.version
        #expect(model.apply(to: original, reportID: version.reportID,
            accountSessionID: version.accountSessionID, editorAllowsApply: true) == nil)
        let applied = try #require(model.apply(to: original, reportID: version.reportID,
            accountSessionID: version.accountSessionID, editorAllowsApply: true, acceptUnfinishedGoal: true))
        var later = applied
        later.codeName = "Manual title"
        let undone = try #require(model.undo(in: later, reportID: version.reportID,
            accountSessionID: version.accountSessionID, editorAllowsApply: true))
        #expect(undone.summaryMessage == original.summaryMessage)
        #expect(undone.codeName == "Manual title")
        #expect(service.requests.count == 2)
    }

    @Test func baseChangesMakeCandidateStaleAndRebaseDiscardsIt() async {
        let model = make(FakeComposer())
        await model.send("Write")
        var current = model.base
        current.summaryMessage = "Manual"
        let version = model.graph.version
        model.observeEditor(current, reportID: version.reportID, accountSessionID: version.accountSessionID)
        #expect(model.graph.state == .stale)
        #expect(model.apply(to: current, reportID: version.reportID,
            accountSessionID: version.accountSessionID, editorAllowsApply: true, acceptUnfinishedGoal: true) == nil)
        model.rebase(on: current)
        #expect(model.candidate == current)
        #expect(model.messages.isEmpty)
    }

    @Test func cancelledLateResponseCannotReplaceCandidate() async {
        let service = FakeComposer()
        service.suspend = true
        let model = make(service)
        let send = Task { await model.send("Write") }
        while service.continuation == nil { await Task.yield() }
        model.cancel()
        service.resume()
        await send.value
        #expect(model.graph.state == .ready)
        #expect(model.candidate == model.base)
        #expect(model.messages.isEmpty)
    }

    @Test func accountSwitchClosesPendingSession() async {
        let service = FakeComposer()
        service.suspend = true
        let model = make(service)
        let send = Task { await model.send("Write") }
        while service.continuation == nil { await Task.yield() }
        model.observeEditor(model.base, reportID: model.graph.version.reportID, accountSessionID: UUID())
        service.resume()
        await send.value
        #expect(model.graph.state == .closed)
        #expect(model.proposal == nil)
    }

    @Test func quotaFailurePreservesCandidate() async {
        let service = FakeComposer()
        let model = make(service)
        await model.send("Write")
        let candidate = model.candidate
        service.failure = .budgetExhausted
        await model.send("Revise")
        #expect(model.graph.state == .limited)
        #expect(model.candidate == candidate)
    }

    @Test func manualCandidateEditsInvalidateReviewWithoutSavingOrCallingAI() async {
        let service = FakeComposer()
        let model = make(service)
        await model.send("Write")
        model.confirm(reviewedCriteria: [.audienceFit, .languageFit, .factualAccuracy])
        #expect(model.graph.state == .confirmed)
        let before = model.base
        var updated = model.candidate
        updated.summaryMessage = "Manually corrected facts"
        model.editCandidate(updated)
        #expect(model.graph.state == .reviewing)
        #expect(model.graph.confirmation == nil)
        #expect(model.candidate.summaryMessage == "Manually corrected facts")
        #expect(model.base == before)
        #expect(model.edits == nil)
        #expect(service.requests.count == 1)
        model.confirm(reviewedCriteria: [.audienceFit, .languageFit, .factualAccuracy])
        #expect(model.graph.state == .confirmed)
        model.reviewAgain()
        #expect(model.graph.state == .reviewing)
        #expect(model.graph.confirmation == nil)
    }

    @Test func candidateEditsCannotChangeImagesOrReviveStaleSession() async {
        let model = make(FakeComposer())
        await model.send("Write")
        let original = model.candidate
        var edited = original
        edited.assets = [ImageAsset(id: UUID(), fileName: "new.png", localReference: "new.png")]
        model.editCandidate(edited)
        #expect(model.candidate == original)
        var current = model.base
        current.summaryMessage = "Editor change"
        model.observeEditor(current, reportID: model.graph.version.reportID,
                            accountSessionID: model.graph.version.accountSessionID)
        edited = original
        edited.summaryMessage = "Late edit"
        model.editCandidate(edited)
        #expect(model.graph.state == .stale)
        #expect(model.candidate == original)
    }

    @Test func selectionInvalidatesConfirmationWithoutNetwork() async {
        let service = FakeComposer()
        let model = make(service)
        await model.send("Write")
        model.confirm(reviewedCriteria: [.audienceFit, .languageFit, .factualAccuracy])
        #expect(model.graph.state == .confirmed)
        model.select(fields: [], metrics: [])
        #expect(model.graph.confirmation == nil)
        #expect(model.candidate == model.base)
        #expect(!model.evaluation.isConfirmed)
        #expect(service.requests.count == 1)
    }
}

@MainActor
private final class FakeComposer: ReportComposing {
    var requests: [CompositionRequest] = []
    var failure: CompositionErrorCode?
    var suspend = false
    var continuation: CheckedContinuation<Void, Never>?

    func resume() { continuation?.resume(); continuation = nil }

    func compose(_ request: CompositionRequest) async throws -> CompositionResponse {
        requests.append(request)
        if suspend { await withCheckedContinuation { continuation = $0 } }
        if let failure { throw CompositionServiceError(code: failure) }
        return CompositionResponse(requestID: request.requestID, baseDraftVersion: request.baseDraftVersion,
            candidateVersion: request.candidateVersion, goalID: request.goal.id, goalRevision: request.goal.revision,
            proposal: CompositionProposal(assistantMessage: "Review", clarifyingQuestions: [],
                proposedChanges: [.init(field: .summaryMessage, operation: .set, value: "Candidate \(requests.count)")],
                metricChanges: [], warnings: [], semanticFindings: []), remainingDailyRequests: 19)
    }
}
