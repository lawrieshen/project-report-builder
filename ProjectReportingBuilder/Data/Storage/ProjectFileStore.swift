import Foundation

nonisolated struct ProjectLoadResult: Sendable {
    var projects: [ProjectReport] = []
    var warnings: [String] = []
}

/// Serialize disk operations away from the main actor.
actor ProjectFileStore {
    let storage: ApplicationStorage

    init(storage: ApplicationStorage) { self.storage = storage }

    func fetchProjects() throws -> ProjectLoadResult {
        try storage.prepare()
        var result = ProjectLoadResult()
        let directories = try FileManager.default.contentsOfDirectory(at: storage.projects,
            includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        for directory in directories {
            guard let id = UUID(uuidString: directory.lastPathComponent) else { continue }
            do {
                if let project = try fetchProject(id: id) { result.projects.append(project) }
            } catch {
                result.warnings.append("\(id.uuidString): \(error.localizedDescription)")
            }
        }
        return result
    }

    func fetchProject(id: UUID) throws -> ProjectReport? {
        let url = storage.projectFile(id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let project = try StoredDocument<ProjectReport>.decode(Data(contentsOf: url))
            guard project.id == id else { throw StorageError.readFailed("project identity") }
            return project
        } catch let error as StorageError { throw error }
        catch { throw StorageError.readFailed(id.uuidString) }
    }

    func save(_ project: ProjectReport) throws {
        do {
            try storage.prepare()
            // Refuse to overwrite an unreadable or newer-format document.
            _ = try fetchProject(id: project.id)
            try FileManager.default.createDirectory(at: storage.projectDirectory(project.id), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(StoredDocument(project))
            try data.write(to: storage.projectFile(project.id), options: .atomic)
        } catch let error as StorageError { throw error }
        catch { throw StorageError.writeFailed("project") }
    }

    func fetchRecovery(projectID: UUID) throws -> RecoverySnapshot? {
        let url = storage.recoveryFile(projectID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let snapshot = try StoredDocument<RecoverySnapshot>.decode(Data(contentsOf: url))
            guard snapshot.projectID == projectID else { throw StorageError.readFailed("recovery identity") }
            guard let project = try fetchProject(id: projectID),
                  project.updatedAt == snapshot.baseUpdatedAt else { return nil }
            return snapshot
        } catch let error as StorageError { throw error }
        catch { throw StorageError.readFailed("recovery copy") }
    }

    func saveRecovery(_ snapshot: RecoverySnapshot) throws {
        guard let project = try fetchProject(id: snapshot.projectID) else { throw StorageError.projectMissing }
        _ = try fetchRecovery(projectID: snapshot.projectID)
        // An older pending write must not resurrect a draft after a successful save.
        guard project.updatedAt == snapshot.baseUpdatedAt else { return }
        do {
            try storage.prepare()
            let data = try JSONEncoder().encode(StoredDocument(snapshot))
            try data.write(to: storage.recoveryFile(snapshot.projectID), options: .atomic)
        } catch { throw StorageError.writeFailed("recovery copy") }
    }

    func deleteRecovery(projectID: UUID) throws {
        let url = storage.recoveryFile(projectID)
        if FileManager.default.fileExists(atPath: url.path) {
            do { try FileManager.default.removeItem(at: url) }
            catch { throw StorageError.writeFailed("recovery cleanup") }
        }
    }

    func assetURL(_ asset: ImageAsset, projectID: UUID) throws -> URL {
        let reference = asset.localReference
        guard !reference.isEmpty, reference != ".", reference != "..",
              !reference.contains("/"), !reference.contains("\\") else { throw StorageError.invalidReference }
        return storage.assets(projectID).appendingPathComponent(reference)
    }

    func writeAsset(_ data: Data, asset: ImageAsset, projectID: UUID) throws {
        guard try fetchProject(id: projectID) != nil else { throw StorageError.projectMissing }
        let url = try assetURL(asset, projectID: projectID)
        try FileManager.default.createDirectory(at: storage.assets(projectID), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func removeAsset(_ asset: ImageAsset, projectID: UUID) throws {
        let url = try assetURL(asset, projectID: projectID)
        let saved = try fetchProject(id: projectID)?.card?.assets ?? []
        let recovered = try fetchRecovery(projectID: projectID)?.draft.assets ?? []
        guard !(saved + recovered).contains(where: { $0.localReference == asset.localReference }) else { return }
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    func delete(id: UUID) throws {
        let directory = storage.projectDirectory(id)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        do { try FileManager.default.removeItem(at: directory) }
        catch { throw StorageError.deleteFailed }
    }
}
