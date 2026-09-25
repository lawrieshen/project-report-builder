import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct LocalProjectRepositoryTests {
    @Test func failedAtomicWritePreservesPreviousDocument() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = ApplicationStorage(root: root)
        let store = ProjectFileStore(storage: storage)
        var project = ProjectReport(id: UUID(), codeName: "Saved", lineOfBusiness: "Camera", status: .draft, createdAt: .now, updatedAt: .now)
        try await store.save(project)
        let directory = storage.projectDirectory(project.id)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: root)
        }
        let before = try Data(contentsOf: storage.projectFile(project.id))
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        project.codeName = "Must not replace saved data"
        await #expect(throws: (any Error).self) { try await store.save(project) }
        #expect(try Data(contentsOf: storage.projectFile(project.id)) == before)
    }

    @Test func survivesReinitializationAndReportsCorruption() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ApplicationStorage(root: root)
        let repository = LocalProjectRepository(store: ProjectFileStore(storage: storage))
        var first = ProjectReport(id: UUID(), codeName: "One", lineOfBusiness: "Camera", status: .draft, createdAt: .now, updatedAt: .now)
        let second = ProjectReport(id: UUID(), codeName: "Two", lineOfBusiness: "Camera", status: .draft, createdAt: .now, updatedAt: .now)
        try await repository.save(first)
        try await repository.save(second)
        first.codeName = "Updated"
        try await repository.save(first)
        let restarted = LocalProjectRepository(store: ProjectFileStore(storage: storage))
        #expect(try await restarted.fetchProject(id: first.id) == first)
        #expect(try await restarted.fetchProjects().count == 2)
        try Data("damaged".utf8).write(to: storage.projectFile(second.id))
        #expect(try await restarted.fetchProjects() == [first])
        #expect(restarted.loadWarnings.count == 1)
        do { try await restarted.save(second); Issue.record("Corrupt data must not be overwritten") }
        catch { }
        #expect(try String(contentsOf: storage.projectFile(second.id), encoding: .utf8) == "damaged")
        try await restarted.delete(first)
        #expect(try await restarted.fetchProject(id: first.id) == nil)
    }
}
