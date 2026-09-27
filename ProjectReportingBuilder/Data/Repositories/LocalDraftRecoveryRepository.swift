import Foundation

/// Adapt the file store to the recovery-only repository interface.
struct LocalDraftRecoveryRepository: DraftRecoveryRepository {
    let store: ProjectFileStore
    func fetchRecovery(projectID: UUID) async throws -> RecoverySnapshot? {
        try await store.fetchRecovery(projectID: projectID)
    }
    func saveRecovery(_ snapshot: RecoverySnapshot) async throws { try await store.saveRecovery(snapshot) }
    func deleteRecovery(projectID: UUID) async throws { try await store.deleteRecovery(projectID: projectID) }
}
