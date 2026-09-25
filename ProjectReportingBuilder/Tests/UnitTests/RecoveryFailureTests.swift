import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct RecoveryFailureTests {
    @Test func cleanupFailureKeepsDiscardDirtyButAllowsSave() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = ApplicationStorage(root: root)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: storage.recovery.path)
            try? FileManager.default.removeItem(at: root)
        }
        let store = ProjectFileStore(storage: storage)
        let repository = LocalProjectRepository(store: store)
        let project = ProjectReport(id: UUID(), codeName: "Saved", lineOfBusiness: "Camera", status: .draft, createdAt: .now, updatedAt: .now)
        try await repository.save(project)
        let recovery = LocalDraftRecoveryRepository(store: store)
        let editor = ReportEditorViewModel(projectID: project.id, repository: repository,
            recoveryRepository: recovery, recoveryDelay: .zero)
        await editor.load()
        editor.draft?.codeName = "New saved value"
        await editor.recoveryTask?.value
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: storage.recovery.path)
        #expect(await editor.discardChanges() == false)
        #expect(editor.isDirty)
        #expect(editor.draft?.codeName == "New saved value")
        #expect(try await recovery.fetchRecovery(projectID: project.id) != nil)
        #expect(await editor.save())
        #expect(!editor.isDirty)
        #expect(editor.saveError == nil)
        #expect(editor.recoveryMessage?.contains("cleanup failed") == true)
        #expect(try await repository.fetchProject(id: project.id)?.codeName == "New saved value")
        #expect(try await recovery.fetchRecovery(projectID: project.id) == nil)
    }
}
