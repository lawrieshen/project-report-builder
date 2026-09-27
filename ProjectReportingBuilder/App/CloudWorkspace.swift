import Foundation

/// Create a fresh repository for each authenticated session, with isolated disk caches.
@MainActor
final class CloudWorkspace {
    let repository: CloudProjectRepository
    let storage: ApplicationStorage
    let files: ProjectFileStore
    let session: AppSessionStore
    let maintenance = RecoveryMaintenanceCoordinator()

    init(root: URL, client: CloudReportClient) throws {
        // The backend admits exactly this configured POC subject. The root view verifies
        // API access before creating this workspace; token claims never grant local access.
        let namespace = "prb-dev-092e2408-5041-706a-684d-db818c51805c"
        storage = ApplicationStorage(root: root.appendingPathComponent("Cloud").appendingPathComponent(namespace))
        files = ProjectFileStore(storage: storage)
        repository = CloudProjectRepository(client: client, files: files,
            images: CloudImageTransfer(files: files, client: client))
        guard let defaults = UserDefaults(suiteName: "CloudWorkspace." + namespace) else {
            throw StorageError.readFailed("cloud workspace preferences")
        }
        session = AppSessionStore(repository: UserDefaultsSessionRepository(defaults: defaults))
    }

    func assets(for id: UUID) -> any AssetRepository {
        LocalAssetRepository(storage: storage, projectID: id, store: files)
    }

    func prepareForSignOut() async throws {
        if let editor = maintenance.participant as? ReportEditorViewModel {
            try await editor.preserveDraftForSignOut()
        }
    }
}
