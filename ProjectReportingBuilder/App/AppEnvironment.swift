import Foundation

/// Choose storage dependencies once for the application session.
@MainActor
struct AppEnvironment {
    let cloudAccount = CloudAccountStore()
    let maintenance = RecoveryMaintenanceCoordinator()
    let session: AppSessionStore
    let settings: AppSettingsStore
    let storage: ApplicationStorage
    let store: ProjectFileStore
    let cloudTransfers: CloudTransferStore
    let projects: LocalProjectRepository

    init(storage: ApplicationStorage, defaults: UserDefaults = .standard,
         initialSettings: AppSettings = .default) {
        session = AppSessionStore(repository: UserDefaultsSessionRepository(defaults: defaults))
        settings = AppSettingsStore(repository: UserDefaultsSettingsRepository(defaults: defaults, initialSettings: initialSettings))
        self.storage = storage
        store = ProjectFileStore(storage: storage)
        projects = LocalProjectRepository(store: store)
        cloudTransfers = CloudTransferStore(projects: projects, client: CloudReportClient(account: cloudAccount),
            history: CloudUploadHistory(file: storage.root.appendingPathComponent("cloud-uploads-prb-dev-092e2408-5041-706a-684d-db818c51805c.json")))
    }

    func assets(for projectID: UUID) -> any AssetRepository {
        LocalAssetRepository(storage: storage, projectID: projectID, store: store)
    }

    static func live() throws -> AppEnvironment {
        #if DEBUG
        let variables = ProcessInfo.processInfo.environment
        if let value = variables["PROJECT_REPORT_TEST_ID"], let id = UUID(uuidString: value) {
            guard let defaults = UserDefaults(suiteName: "ProjectReportUITests." + id.uuidString) else {
                throw StorageError.readFailed("test preferences")
            }
            var initial = AppSettings.default
            if variables["PROJECT_REPORT_MANUAL_SAVE"] == "1" {
                initial.autosaveEnabled = false
                initial.restoreWorkspaceAfterInterruption = false
            }
            return AppEnvironment(storage: ApplicationStorage(root: FileManager.default.temporaryDirectory
                .appendingPathComponent("ProjectReportUITests").appendingPathComponent(id.uuidString)),
                defaults: defaults, initialSettings: initial)
        }
        if variables["XCTestConfigurationFilePath"] != nil {
            guard let defaults = UserDefaults(suiteName: "ProjectReportUnitTests." + UUID().uuidString) else {
                throw StorageError.readFailed("test preferences")
            }
            return AppEnvironment(storage: ApplicationStorage(root: FileManager.default.temporaryDirectory
                .appendingPathComponent("ProjectReportUnitTests").appendingPathComponent(UUID().uuidString)), defaults: defaults)
        }
        #endif
        return AppEnvironment(storage: try ApplicationStorage.production())
    }
}
