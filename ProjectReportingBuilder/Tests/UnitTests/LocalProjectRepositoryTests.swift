import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct LocalProjectRepositoryTests {
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
