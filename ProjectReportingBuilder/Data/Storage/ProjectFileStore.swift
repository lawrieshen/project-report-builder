import Foundation

struct ProjectLoadResult {
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

    func delete(id: UUID) throws {
        let directory = storage.projectDirectory(id)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        do { try FileManager.default.removeItem(at: directory) }
        catch { throw StorageError.deleteFailed }
    }
}
