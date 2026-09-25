import Foundation

/// Choose storage dependencies once for the application session.
@MainActor
struct AppEnvironment {
    let storage: ApplicationStorage
    let store: ProjectFileStore
    let projects: LocalProjectRepository

    init(storage: ApplicationStorage) {
        self.storage = storage
        store = ProjectFileStore(storage: storage)
        projects = LocalProjectRepository(store: store)
    }

    func assets(for projectID: UUID) -> any AssetRepository {
        LocalAssetRepository(storage: storage, projectID: projectID, store: store)
    }

    static func live() throws -> AppEnvironment {
        #if DEBUG
        let variables = ProcessInfo.processInfo.environment
        if let value = variables["PROJECT_REPORT_TEST_ID"], let id = UUID(uuidString: value) {
            return AppEnvironment(storage: ApplicationStorage(root: FileManager.default.temporaryDirectory
                .appendingPathComponent("ProjectReportUITests").appendingPathComponent(id.uuidString)))
        }
        if variables["XCTestConfigurationFilePath"] != nil {
            return AppEnvironment(storage: ApplicationStorage(root: FileManager.default.temporaryDirectory
                .appendingPathComponent("ProjectReportUnitTests").appendingPathComponent(UUID().uuidString)))
        }
        #endif
        return AppEnvironment(storage: try ApplicationStorage.production())
    }
}
