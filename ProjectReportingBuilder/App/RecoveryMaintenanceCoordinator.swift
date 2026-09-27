import Foundation
import Observation

@MainActor
protocol RecoveryMaintenanceParticipant: AnyObject {
    var canClearRecovery: Bool { get }
    func prepareForRecoveryCleanup() async throws
    func finishRecoveryCleanup(succeeded: Bool)
}

nonisolated enum RecoveryMaintenanceError: LocalizedError {
    case workspaceBusy
    var errorDescription: String? { "Wait for the current report operation to finish, then try again." }
}

/// Coordinate recovery cleanup with the active workspace's pending writes.
@MainActor
@Observable
final class RecoveryMaintenanceCoordinator {
    @ObservationIgnored weak var participant: (any RecoveryMaintenanceParticipant)?
    private(set) var isClearing = false

    /// Clear recovery copies after coordinating with the active workspace.
    ///
    /// - Parameter store: The local store containing recovery files.
    /// - Throws: `RecoveryMaintenanceError.workspaceBusy` when cleanup is unavailable,
    ///   or an error from workspace preparation or storage cleanup.
    func clearRecovery(using store: ProjectFileStore) async throws {
        guard !isClearing, participant?.canClearRecovery != false else {
            throw RecoveryMaintenanceError.workspaceBusy
        }
        isClearing = true
        defer { isClearing = false }
        let current = participant
        try await current?.prepareForRecoveryCleanup()
        do {
            try await store.clearRecoveryDrafts()
            current?.finishRecoveryCleanup(succeeded: true)
        } catch {
            current?.finishRecoveryCleanup(succeeded: false)
            throw error
        }
    }
}
