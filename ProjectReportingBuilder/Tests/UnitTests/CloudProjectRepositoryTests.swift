import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct CloudProjectRepositoryTests {
    @Test func preservesIdentityAndDoesNotAdoptListingRevision() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let client = try PrimaryClientStub()
        let repository = CloudProjectRepository(client: client, files: ProjectFileStore(storage: ApplicationStorage(root: root)))
        var project = try #require(try await repository.fetchProject(id: client.report.id))
        #expect(project.id == client.report.id)
        client.report.revision = 7
        _ = try await repository.fetchProjects()
        project.codeName = "Edited"
        try await repository.save(project)
        #expect(client.revisions == [1])
        repository.invalidate()
        await #expect(throws: (any Error).self) { try await repository.save(project) }
        #expect(client.revisions == [1])
    }

    @Test func invalidatedSessionIgnoresAResponseAlreadyInFlight() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let client = try PrimaryClientStub()
        let storage = ApplicationStorage(root: root)
        let repository = CloudProjectRepository(client: client, files: ProjectFileStore(storage: storage))
        client.onGet = { repository.invalidate() }
        await #expect(throws: (any Error).self) { try await repository.fetchProject(id: client.report.id) }
        #expect(!FileManager.default.fileExists(atPath: storage.projectFile(client.report.id).path))
    }

    @Test func deleteUsesTheDisplayedRevision() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let client = try PrimaryClientStub()
        let repository = CloudProjectRepository(client: client, files: ProjectFileStore(storage: ApplicationStorage(root: root)))
        let projects = try await repository.fetchProjects()
        client.report.revision = 2
        try await repository.delete(projects[0])
        #expect(client.deletedRevision == 1)
    }
}

@MainActor
private final class PrimaryClientStub: CloudReportServing {
    var report: CloudReport
    var revisions: [Int64] = []
    var onGet: (() -> Void)?
    var deletedRevision: Int64?
    init() throws {
        let project = ProjectReport(id: UUID(), codeName: "Test", lineOfBusiness: "Mac", status: .draft,
            card: nil, createdAt: .now, updatedAt: .now)
        report = CloudReport(reportID: project.id, ownerID: "approved", revision: 1,
            schemaVersion: 2, updatedAt: "2026-09-27T00:00:00Z", report: try CloudReportContent(project: project))
    }
    func list(after: UUID?) async throws -> CloudReportPage { CloudReportPage(items: [report], nextCursor: nil) }
    func get(id: UUID) async throws -> CloudReport { onGet?(); return report }
    func save(id: UUID, revision: Int64, content: CloudReportContent) async throws -> CloudReport {
        revisions.append(revision)
        report.report = content
        report.revision = revision + 1
        return report
    }
    func delete(id: UUID, revision: Int64) async throws { deletedRevision = revision }
}
