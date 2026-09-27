import Foundation

/// Preserve raw unsaved input separately from the last explicit save.
nonisolated struct RecoverySnapshot: Codable, Equatable, Sendable {
    let projectID: UUID
    let baseUpdatedAt: Date
    let capturedAt: Date
    let draft: ReportEditorDraft
}

/// Store recovery snapshots without replacing explicitly saved reports.
protocol DraftRecoveryRepository: Sendable {
    /// Look up unsaved input for a project.
    /// - Parameter projectID: The identity of the report being recovered.
    /// - Returns: Its recovery snapshot, or `nil` when none exists.
    /// - Throws: An error if recovery data cannot be read.
    func fetchRecovery(projectID: UUID) async throws -> RecoverySnapshot?
    func saveRecovery(_ snapshot: RecoverySnapshot) async throws
    func deleteRecovery(projectID: UUID) async throws
}
