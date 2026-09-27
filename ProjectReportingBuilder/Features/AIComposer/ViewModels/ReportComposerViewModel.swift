import Combine
import Foundation

/// Coordinate one in-memory composition session; editor writes remain explicit caller actions.
@MainActor
final class ReportComposerViewModel: ObservableObject {
    @Published private(set) var graph: ComposerStateGraph
    @Published private(set) var candidate: ReportEditorDraft
    @Published private(set) var messages: [CompositionMessage] = []
    @Published private(set) var proposal: CompositionProposal?
    @Published private(set) var errorMessage: String?
    @Published private(set) var remainingDailyRequests: Int?
    @Published private(set) var selectedFields: Set<CompositionTextChange.Field> = []
    @Published private(set) var selectedMetrics: Set<UUID> = []
    private(set) var base: ReportEditorDraft
    private(set) var edits: CompositionEdits?
    private var assessment: CompositionAssessment?
    private var undoRecord: CompositionUndo?
    private var requestTask: Task<CompositionResponse, Error>?
    private let service: any ReportComposing

    init(draft: ReportEditorDraft, reportID: UUID, accountSessionID: UUID,
         goal: ReportCompositionGoal = ReportCompositionGoal(), service: any ReportComposing) {
        base = draft
        candidate = draft
        self.service = service
        graph = ComposerStateGraph(version: CompositionVersion(accountSessionID: accountSessionID,
            reportID: reportID, baseDraftVersion: UUID(), goal: goal, candidateVersion: UUID()))
    }

    var evaluation: GoalEvaluation {
        GoalEvaluator.evaluate(draft: candidate, version: graph.version,
            assessment: assessment, confirmation: graph.confirmation)
    }

    var hasUnappliedChanges: Bool { candidate != base }
    var canUndo: Bool { undoRecord != nil && graph.state != .closed }

    /// Send one explicit turn; cancellation and version changes make late results inert.
    func send(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf16.count <= 8_000 else {
            errorMessage = "Enter a message of up to 8,000 characters."
            return
        }
        guard messages.count < 12 else {
            errorMessage = "This conversation is full. Start again from the current draft."
            return
        }
        let version = graph.version
        let id = UUID()
        guard graph.send(.send(requestID: id, version: version)) else { return }
        errorMessage = nil
        let history = messages + [CompositionMessage(role: .user, text: text)]
        let submitted = candidate
        let request = CompositionRequest(requestID: id, baseDraftVersion: version.baseDraftVersion,
            candidateVersion: version.candidateVersion, goal: version.goal,
            draft: CompositionDraft(draft: submitted), messages: history)
        let task = Task { try await service.compose(request) }
        requestTask = task
        do {
            let response = try await task.value
            guard graph.state == .generating(requestID: id), graph.version == version else { return }
            guard response.matches(request), (0...20).contains(response.remainingDailyRequests) else {
                throw CompositionEditError.invalidProposal
            }
            let changes = try CompositionEdits(base: submitted, proposal: response.proposal)
            guard graph.send(.received(requestID: id, version: version, candidateVersion: UUID())) else { return }
            edits = changes
            selectedFields = changes.fields
            selectedMetrics = changes.metricIDs
            candidate = changes.proposed
            proposal = response.proposal
            messages = history + [CompositionMessage(role: .assistant, text: response.proposal.assistantMessage)]
            remainingDailyRequests = response.remainingDailyRequests
            assessment = CompositionAssessment(version: graph.version, findings: response.proposal.semanticFindings)
            graph.send(.evaluated(hasQuestions: !response.proposal.clarifyingQuestions.isEmpty))
            requestTask = nil
        } catch {
            let code = (error as? CompositionServiceError)?.code
            let limited = code == .dailyQuota || code == .budgetExhausted || code == .rateLimited
            guard graph.send(.failure(requestID: id, limited: limited)) else { return }
            errorMessage = limited
                ? "AI usage is currently limited. You can continue editing and saving manually."
                : "AI could not complete this request. Your draft and previous candidate are unchanged."
            requestTask = nil
        }
    }

    /// Reevaluate the selected draft locally, without a provider call or inherited confirmation.
    func select(fields: Set<CompositionTextChange.Field>, metrics: Set<UUID>) {
        guard let edits else { return }
        let updated = version(goal: graph.version.goal)
        guard graph.send(.candidateChanged(updated)) else { return }
        requestTask?.cancel()
        requestTask = nil
        selectedFields = fields.intersection(edits.fields)
        selectedMetrics = metrics.intersection(edits.metricIDs)
        candidate = edits.selecting(fields: selectedFields, metrics: selectedMetrics)
        assessment = nil
        graph.send(.evaluated(hasQuestions: false))
    }

    func changeGoal(_ goal: ReportCompositionGoal) {
        guard graph.send(.candidateChanged(version(goal: goal))) else { return }
        requestTask?.cancel()
        requestTask = nil
        assessment = nil
        graph.send(.evaluated(hasQuestions: false))
    }

    func confirm(reviewedCriteria: Set<GoalCriterion.ID>) {
        let confirmation = GoalConfirmation(version: graph.version, reviewedCriteria: reviewedCriteria)
        let reviewed = GoalEvaluator.evaluate(draft: candidate, version: graph.version,
            assessment: assessment, confirmation: confirmation)
        graph.send(.confirm(reviewed, confirmation))
    }

    /// Return one draft for the editor to assign and autosave after checking its live identity and state.
    func apply(to current: ReportEditorDraft, reportID: UUID, accountSessionID: UUID,
               editorAllowsApply: Bool, acceptUnfinishedGoal: Bool = false) -> ReportEditorDraft? {
        guard matches(reportID: reportID, accountSessionID: accountSessionID), current == base else {
            invalidate()
            return nil
        }
        guard graph.send(.apply(version: graph.version, editorAllowsApply: editorAllowsApply,
                                acceptUnfinishedGoal: acceptUnfinishedGoal)) else { return nil }
        undoRecord = CompositionUndo(before: current, after: candidate)
        return candidate
    }

    /// Preserve unrelated manual changes; a conflict requires a deliberate user decision.
    func undo(in current: ReportEditorDraft, reportID: UUID, accountSessionID: UUID,
              editorAllowsApply: Bool) -> ReportEditorDraft? {
        guard graph.state != .closed, editorAllowsApply,
              matches(reportID: reportID, accountSessionID: accountSessionID), let undoRecord else { return nil }
        do {
            let restored = try undoRecord.restoring(current)
            self.undoRecord = nil
            invalidate()
            rebase(on: restored)
            return restored
        } catch {
            errorMessage = "Some applied fields were edited again. Undo was stopped to preserve those changes."
            return nil
        }
    }

    func observeEditor(_ draft: ReportEditorDraft, reportID: UUID, accountSessionID: UUID) {
        guard matches(reportID: reportID, accountSessionID: accountSessionID) else { close(); return }
        guard draft != base else { return }
        let isAppliedDraft = graph.state == .applied && draft == candidate
        invalidate()
        if isAppliedDraft { rebase(on: draft) }
    }

    /// Discard old proposals explicitly and start from the latest editor snapshot.
    func rebase(on draft: ReportEditorDraft) {
        let updated = CompositionVersion(accountSessionID: graph.version.accountSessionID,
            reportID: graph.version.reportID, baseDraftVersion: UUID(), goal: graph.version.goal, candidateVersion: UUID())
        guard graph.send(.rebase(updated)) else { return }
        base = draft
        candidate = draft
        edits = nil
        proposal = nil
        assessment = nil
        selectedFields = []
        selectedMetrics = []
        messages = []
        errorMessage = nil
        graph.send(.evaluated(hasQuestions: false))
    }

    func cancel() {
        guard graph.send(.cancel) else { return }
        requestTask?.cancel()
        requestTask = nil
    }

    func close() {
        graph.send(.close)
        requestTask?.cancel()
        requestTask = nil
        messages = []
        proposal = nil
        assessment = nil
        edits = nil
        undoRecord = nil
        candidate = base
    }

    private func invalidate() {
        graph.send(.baseChanged)
        requestTask?.cancel()
        requestTask = nil
        assessment = nil
    }

    private func matches(reportID: UUID, accountSessionID: UUID) -> Bool {
        graph.version.reportID == reportID && graph.version.accountSessionID == accountSessionID
    }

    private func version(goal: ReportCompositionGoal) -> CompositionVersion {
        CompositionVersion(accountSessionID: graph.version.accountSessionID, reportID: graph.version.reportID,
            baseDraftVersion: graph.version.baseDraftVersion, goal: goal, candidateVersion: UUID())
    }
}
