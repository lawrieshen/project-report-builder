import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct RecoveryBackupTests {
    @Test func rapidEditsSaveAndDiscardKeepSeparateStates() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ApplicationStorage(root: root)
        let store = ProjectFileStore(storage: storage)
        let repository = LocalProjectRepository(store: store)
        let recovery = LocalDraftRecoveryRepository(store: store)
        let project = ProjectReport(id: UUID(), codeName: "Saved", lineOfBusiness: "Camera", status: .draft, createdAt: .now, updatedAt: .now)
        try await repository.save(project)
        let editor = ReportEditorViewModel(projectID: project.id, repository: repository,
            recoveryRepository: recovery, recoveryDelay: .milliseconds(10))
        await editor.load()
        editor.draft?.codeName = "First"
        editor.draft?.codeName = "Latest"
        await editor.recoveryTask?.value
        #expect(try await recovery.fetchRecovery(projectID: project.id)?.draft.codeName == "Latest")
        #expect(try await repository.fetchProject(id: project.id) == project)
        #expect(editor.isDirty)
        editor.draft?.codeName = "Pending discard"
        await editor.discardChanges()
        await editor.recoveryTask?.value
        #expect(try await recovery.fetchRecovery(projectID: project.id) == nil)
        #expect(!editor.isDirty)
        editor.draft?.codeName = "Commit this"
        #expect(await editor.save())
        await editor.recoveryTask?.value
        #expect(try await recovery.fetchRecovery(projectID: project.id) == nil)
        #expect(try await repository.fetchProject(id: project.id)?.codeName == "Commit this")
        #expect(!editor.isDirty)
    }
}
