import Foundation
import Observation

/// Choose storage dependencies once for the application session.
@MainActor @Observable
final class AppEnvironment {
    let usesCloudStorage: Bool
    var workspace: CloudWorkspace?
    let cloudAccount: CloudAccountStore
    let maintenance = RecoveryMaintenanceCoordinator()
    let session: AppSessionStore
    let settings: AppSettingsStore
    let storage: ApplicationStorage
    let store: ProjectFileStore
    let cloudTransfers: CloudTransferStore
    let projects: LocalProjectRepository

    init(storage: ApplicationStorage, defaults: UserDefaults = .standard,
         initialSettings: AppSettings = .default, usesCloudStorage: Bool = false, cloudAccount: CloudAccountStore? = nil) {
        self.cloudAccount = cloudAccount ?? CloudAccountStore()
        self.usesCloudStorage = usesCloudStorage
        session = AppSessionStore(repository: UserDefaultsSessionRepository(defaults: defaults))
        settings = AppSettingsStore(repository: UserDefaultsSettingsRepository(defaults: defaults, initialSettings: initialSettings))
        self.storage = storage
        store = ProjectFileStore(storage: storage)
        projects = LocalProjectRepository(store: store)
        let cloudClient = CloudReportClient(account: self.cloudAccount)
        cloudTransfers = CloudTransferStore(projects: projects, client: cloudClient,
            history: CloudUploadHistory(file: storage.root.appendingPathComponent("cloud-uploads-prb-dev-092e2408-5041-706a-684d-db818c51805c.json")),
            images: CloudImageTransfer(files: store, client: cloudClient))
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
                defaults: defaults, initialSettings: initial,
                usesCloudStorage: variables["PROJECT_REPORT_TEST_CLOUD_GATE"] == "1",
                cloudAccount: CloudAccountStore(credentials: EmptyTestCloudCredentials(), client: CognitoTokenClient()))
        }
        if variables["XCTestConfigurationFilePath"] != nil {
            guard let defaults = UserDefaults(suiteName: "ProjectReportUnitTests." + UUID().uuidString) else {
                throw StorageError.readFailed("test preferences")
            }
            return AppEnvironment(storage: ApplicationStorage(root: FileManager.default.temporaryDirectory
                .appendingPathComponent("ProjectReportUnitTests").appendingPathComponent(UUID().uuidString)), defaults: defaults)
        }
        #endif
        return AppEnvironment(storage: try ApplicationStorage.production(), usesCloudStorage: true)
    }
}

#if DEBUG
private struct EmptyTestCloudCredentials: CloudCredentialStoring {
    func read() throws -> String? { nil }
    func save(_ token: String) throws { throw CloudAuthError.expiredSession }
    func delete() throws { }
}
#endif
