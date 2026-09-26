import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct SaveConcurrencyTests {
    @Test func saveAndMaintenanceNeverOverlapProjectWrites() async throws {
        let report = ProjectReport(id: UUID(), codeName: "Original", lineOfBusiness: "iPhone",
                                   status: .active, createdAt: .now, updatedAt: .now)
        let repository = SuspendedSaveRepository(project: report)
        let editor = ReportEditorViewModel(projectID: report.id, repository: repository)
        await editor.load()
        editor.draft?.codeName = "Submitted"
        let firstSave = Task { await editor.save() }
        for _ in 0..<100 where repository.continuation == nil { await Task.yield() }
        let continuation = try #require(repository.continuation)
        #expect(editor.saveState == .saving)
        #expect(await editor.save() == false)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let maintenance = RecoveryMaintenanceCoordinator()
        maintenance.participant = editor
        await #expect(throws: RecoveryMaintenanceError.self) {
            try await maintenance.clearRecovery(using: ProjectFileStore(storage: ApplicationStorage(root: root)))
        }
        editor.draft?.codeName = "Newer edit"
        continuation.resume()
        #expect(await firstSave.value)
        #expect(repository.saveCount == 1)
        #expect(repository.project.codeName == "Submitted")
        #expect(editor.draft?.codeName == "Newer edit")
        #expect(editor.isDirty)
    }
}

@MainActor
private final class SuspendedSaveRepository: ProjectRepository {
    var project: ProjectReport
    var saveCount = 0
    var continuation: CheckedContinuation<Void, Never>?
    init(project: ProjectReport) { self.project = project }
    func fetchProjects() async throws -> [ProjectReport] { [project] }
    func fetchProject(id: UUID) async throws -> ProjectReport? { project }
    func save(_ project: ProjectReport) async throws {
        saveCount += 1
        await withCheckedContinuation { continuation = $0 }
        self.project = project
    }
    func delete(_ project: ProjectReport) async throws {}
}
