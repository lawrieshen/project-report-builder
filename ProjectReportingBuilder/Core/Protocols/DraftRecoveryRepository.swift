import Foundation

/// Preserve raw unsaved input separately from the last explicit save.
nonisolated struct RecoverySnapshot: Codable, Equatable, Sendable {
    let projectID: UUID
    let baseUpdatedAt: Date
    let capturedAt: Date
    let draft: ReportEditorDraft
}

/// Store recoverable input independently of canonical report saves.
protocol DraftRecoveryRepository: Sendable {
    /// Read a project recovery snapshot.
    ///
    /// - Parameter projectID: The project whose recovery copy is requested.
    /// - Returns: A snapshot, or `nil` when none exists.
    /// - Throws: An error if recovery data cannot be loaded.
    func fetchRecovery(projectID: UUID) async throws -> RecoverySnapshot?
    /// Persist raw draft input for later recovery.
    ///
    /// - Parameter snapshot: The draft and saved revision it was based on.
    /// - Throws: An error if the recovery write fails.
    func saveRecovery(_ snapshot: RecoverySnapshot) async throws
    /// Remove a project recovery copy.
    ///
    /// - Parameter projectID: The project whose recovery copy should be removed.
    /// - Throws: An error if cleanup fails.
    func deleteRecovery(projectID: UUID) async throws
}
