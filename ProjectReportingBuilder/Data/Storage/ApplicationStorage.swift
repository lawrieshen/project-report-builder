import Foundation

/// Resolve managed paths without exposing file-system details to feature views.
nonisolated struct ApplicationStorage: Sendable {
    let root: URL
    var projects: URL { root.appendingPathComponent("Projects", isDirectory: true) }
    var recovery: URL { root.appendingPathComponent("Recovery", isDirectory: true) }

    static func production() throws -> ApplicationStorage {
        let support = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        return ApplicationStorage(root: support.appendingPathComponent("ProjectReportingBuilder", isDirectory: true))
    }

    func projectDirectory(_ id: UUID) -> URL { projects.appendingPathComponent(id.uuidString, isDirectory: true) }
    func projectFile(_ id: UUID) -> URL { projectDirectory(id).appendingPathComponent("project.json") }
    func assets(_ id: UUID) -> URL { projectDirectory(id).appendingPathComponent("Assets", isDirectory: true) }
    func recoveryFile(_ id: UUID) -> URL { recovery.appendingPathComponent(id.uuidString + ".json") }

    func prepare() throws {
        for directory in [projects, recovery] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
