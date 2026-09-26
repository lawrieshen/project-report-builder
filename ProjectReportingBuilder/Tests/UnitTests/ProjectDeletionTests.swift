import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct ProjectDeletionTests {
    @Test func archivePreservesRecoveryAndDeletePreventsResurrection() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ApplicationStorage(root: root)
        let store = ProjectFileStore(storage: storage)
        let repository = LocalProjectRepository(store: store)
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone", status: .active, createdAt: .now, updatedAt: .now)
        try await repository.save(project)
        var draft = ReportEditorDraft(project: project)
        draft.codeName = "Unsaved"
        let snapshot = RecoverySnapshot(projectID: project.id, baseUpdatedAt: project.updatedAt, capturedAt: .now, draft: draft)
        try await store.saveRecovery(snapshot)
        let browser = ProjectBrowserViewModel(repository: repository)
        await browser.archiveProject(project)
        #expect(try await repository.fetchProject(id: project.id)?.status == .archived)
        #expect(try await store.fetchRecovery(projectID: project.id) == snapshot)
        try await repository.delete(project)
        #expect(!FileManager.default.fileExists(atPath: storage.projectDirectory(project.id).path))
        #expect(!FileManager.default.fileExists(atPath: storage.recoveryFile(project.id).path))
        await #expect(throws: (any Error).self) { try await store.saveRecovery(snapshot) }
        #expect(try await repository.fetchProjects().isEmpty)
    }
}
