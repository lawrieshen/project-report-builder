import Foundation

nonisolated struct ProjectLoadResult: Sendable {
    var projects: [ProjectReport] = []
    var warnings: [String] = []
}

/// Serialize disk operations away from the main actor.
actor ProjectFileStore {
    let storage: ApplicationStorage
    private var maintenanceWarnings: [String] = []

    init(storage: ApplicationStorage) { self.storage = storage }

    func fetchProjects() throws -> ProjectLoadResult {
        try storage.prepare()
        recoverPendingDeletes()
        var result = ProjectLoadResult(warnings: maintenanceWarnings)
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

    func duplicate(id: UUID, codeName: String) throws -> ProjectReport {
        guard let original = try fetchProject(id: id) else { throw StorageError.projectMissing }
        let name = codeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw StorageError.writeFailed("project name") }
        let copy = original.duplicated(codeName: name)
        let staging = storage.projects.appendingPathComponent(".copy-" + copy.id.uuidString)
        do {
            let assets = staging.appendingPathComponent("Assets", isDirectory: true)
            try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
            for (source, destination) in zip(original.card?.assets ?? [], copy.card?.assets ?? []) {
                try FileManager.default.copyItem(at: assetURL(source, projectID: id),
                    to: assets.appendingPathComponent(destination.localReference))
            }
            try JSONEncoder().encode(StoredDocument(copy)).write(to: staging.appendingPathComponent("project.json"), options: .atomic)
            try FileManager.default.moveItem(at: staging, to: storage.projectDirectory(copy.id))
            return copy
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw StorageError.writeFailed("project copy")
        }
    }

    /// Commit deletion by renaming first; unfinished cleanup is retried on the next load.
    func delete(id: UUID) throws {
        let directory = storage.projectDirectory(id)
        let tombstone = storage.projects.appendingPathComponent(".deleted-" + id.uuidString)
        if FileManager.default.fileExists(atPath: directory.path) {
            do { try FileManager.default.moveItem(at: directory, to: tombstone) }
            catch { throw StorageError.deleteFailed }
        }
        finishDelete(id: id, tombstone: tombstone)
    }

    private func finishDelete(id: UUID, tombstone: URL) {
        do {
            try deleteRecovery(projectID: id)
            if FileManager.default.fileExists(atPath: tombstone.path) {
                try FileManager.default.removeItem(at: tombstone)
            }
        } catch {
            maintenanceWarnings.append("Project deleted, but some files still need cleanup: " + id.uuidString)
        }
    }

    private func recoverPendingDeletes() {
        maintenanceWarnings = []
        do {
            for url in try FileManager.default.contentsOfDirectory(at: storage.projects, includingPropertiesForKeys: nil) {
                let name = url.lastPathComponent
                guard name.hasPrefix(".deleted-"), let id = UUID(uuidString: String(name.dropFirst(9))) else { continue }
                finishDelete(id: id, tombstone: url)
            }
        } catch { maintenanceWarnings.append("Unable to inspect pending file cleanup.") }
    }
}
