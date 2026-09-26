import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct RecoveryRestoreTests {
    @Test func restoreRemainsDirtyAndDiscardRemovesRecovery() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ProjectFileStore(storage: ApplicationStorage(root: root))
        let repository = LocalProjectRepository(store: store)
        let recovery = LocalDraftRecoveryRepository(store: store)
        let project = ProjectReport(id: UUID(), codeName: "Saved", lineOfBusiness: "iPhone", status: .draft, createdAt: .now, updatedAt: .now)
        try await repository.save(project)
        var draft = ReportEditorDraft(project: project)
        draft.codeName = "Recovered"
        let snapshot = RecoverySnapshot(projectID: project.id, baseUpdatedAt: project.updatedAt, capturedAt: .now, draft: draft)
        try await recovery.saveRecovery(snapshot)
        let editor = ReportEditorViewModel(projectID: project.id, repository: repository,
            recoveryRepository: recovery, recoveryDelay: .zero)
        await editor.load()
        #expect(editor.pendingRecovery == snapshot)
        #expect(!editor.isDirty)
        editor.restoreRecovery()
        #expect(editor.isDirty)
        #expect(editor.draft == draft)
        #expect(try await repository.fetchProject(id: project.id) == project)
        await editor.recoveryTask?.value
        let reopened = ReportEditorViewModel(projectID: project.id, repository: repository, recoveryRepository: recovery)
        await reopened.load()
        await reopened.discardRecovery()
        #expect(reopened.pendingRecovery == nil)
        #expect(!reopened.isDirty)
        #expect(reopened.draft?.codeName == "Saved")
        #expect(try await recovery.fetchRecovery(projectID: project.id) == nil)
    }
}
