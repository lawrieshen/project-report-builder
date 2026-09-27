import Foundation

nonisolated enum ComposerState: Equatable, Sendable {
    case ready
    case generating(requestID: UUID)
    case evaluating
    case awaitingAnswer
    case reviewing
    case confirmed
    case applied
    case stale
    case failed
    case limited
    case closed
}

nonisolated enum ComposerEvent: Sendable {
    case send(requestID: UUID, version: CompositionVersion)
    case received(requestID: UUID, version: CompositionVersion, candidateVersion: UUID)
    case evaluated(hasQuestions: Bool)
    case confirm(GoalEvaluation, GoalConfirmation)
    case apply(version: CompositionVersion, editorAllowsApply: Bool, acceptUnfinishedGoal: Bool)
    case candidateChanged(CompositionVersion)
    case baseChanged
    case rebase(CompositionVersion)
    case failure(requestID: UUID, limited: Bool)
    case cancel
    case close
}

/// Guard workflow transitions without networking, editor writes, or save-state side effects.
nonisolated struct ComposerStateGraph: Equatable, Sendable {
    private(set) var state: ComposerState = .ready
    private(set) var version: CompositionVersion
    private(set) var confirmation: GoalConfirmation?

    init(version: CompositionVersion) { self.version = version }

    /// Return false for illegal transitions or results belonging to an obsolete request.
    @discardableResult
    mutating func send(_ event: ComposerEvent) -> Bool {
        guard state != .closed else { return false }
        switch event {
        case .close:
            state = .closed
            confirmation = nil
        case .baseChanged:
            state = .stale
            confirmation = nil
        case let .send(requestID, expected):
            guard [.ready, .awaitingAnswer, .reviewing, .confirmed, .applied, .failed, .limited].contains(state),
                  expected == version, version.goal.isSupported else { return false }
            state = .generating(requestID: requestID)
            confirmation = nil
        case let .received(requestID, expected, candidateVersion):
            guard state == .generating(requestID: requestID), expected == version,
                  candidateVersion != version.candidateVersion else { return false }
            version = CompositionVersion(accountSessionID: version.accountSessionID, reportID: version.reportID,
                baseDraftVersion: version.baseDraftVersion, goal: version.goal, candidateVersion: candidateVersion)
            state = .evaluating
        case let .evaluated(hasQuestions):
            guard state == .evaluating else { return false }
            state = hasQuestions ? .awaitingAnswer : .reviewing
        case let .confirm(evaluation, accepted):
            guard state == .reviewing, evaluation.version == version, accepted.version == version,
                  evaluation.readyForReview, evaluation.isConfirmed,
                  evaluation.criteria.filter({ $0.evidence == .userConfirmation })
                    .allSatisfy({ accepted.reviewedCriteria.contains($0.id) }) else { return false }
            confirmation = accepted
            state = .confirmed
        case let .apply(expected, editorAllowsApply, acceptUnfinishedGoal):
            guard expected == version, editorAllowsApply,
                  state == .confirmed || (state == .reviewing && acceptUnfinishedGoal) else { return false }
            state = .applied
        case let .candidateChanged(updated):
            guard state != .stale, sameEditor(updated), updated.baseDraftVersion == version.baseDraftVersion,
                  updated.candidateVersion != version.candidateVersion, updated.goal.isSupported,
                  validGoalChange(updated.goal) else { return false }
            version = updated
            confirmation = nil
            state = .evaluating
        case let .rebase(updated):
            guard state == .stale, sameEditor(updated), updated.goal.isSupported,
                  updated.candidateVersion != version.candidateVersion,
                  validGoalChange(updated.goal) else { return false }
            version = updated
            confirmation = nil
            state = .evaluating
        case let .failure(requestID, limited):
            guard state == .generating(requestID: requestID) else { return false }
            state = limited ? .limited : .failed
        case .cancel:
            guard case .generating = state else { return false }
            state = .ready
        }
        return true
    }

    private func sameEditor(_ updated: CompositionVersion) -> Bool {
        updated.accountSessionID == version.accountSessionID && updated.reportID == version.reportID
    }

    private func validGoalChange(_ updated: ReportCompositionGoal) -> Bool {
        updated == version.goal || (updated.id == version.goal.id && updated.revision > version.goal.revision)
    }
}
