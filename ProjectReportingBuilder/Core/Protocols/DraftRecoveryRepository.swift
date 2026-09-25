import Foundation

/// Preserve raw unsaved input separately from the last explicit save.
nonisolated struct RecoverySnapshot: Codable, Equatable, Sendable {
    let projectID: UUID
    let baseUpdatedAt: Date
    let capturedAt: Date
    let draft: ReportEditorDraft
}

protocol DraftRecoveryRepository: Sendable {
    func fetchRecovery(projectID: UUID) async throws -> RecoverySnapshot?
    func saveRecovery(_ snapshot: RecoverySnapshot) async throws
    func deleteRecovery(projectID: UUID) async throws
}
