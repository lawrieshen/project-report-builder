import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct AutosaveRecoveryTests {
    @Test func disabledAutosaveKeepsRecoveryAndEnabledSaveClearsIt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ProjectFileStore(storage: ApplicationStorage(root: root))
        let repository = LocalProjectRepository(store: store)
        let recovery = LocalDraftRecoveryRepository(store: store)
        let project = ProjectReport(id: UUID(), codeName: "Original", lineOfBusiness: "Camera",
                                    status: .active, createdAt: .now, updatedAt: .now)
        try await repository.save(project)
        var preferences = AppSettings.default
        preferences.autosaveEnabled = false
        preferences.autosaveDelay = .seconds1
        let settings = AppSettingsStore(repository: MemorySettingsRepository(preferences))
        let editor = ReportEditorViewModel(projectID: project.id, repository: repository,
            recoveryRepository: recovery, recoveryDelay: .zero, settings: settings)
        await editor.load()
        editor.draft?.codeName = "Recovered"
        await editor.recoveryTask?.value
        #expect(editor.saveState == .unsaved)
        #expect(try await recovery.fetchRecovery(projectID: project.id)?.draft.codeName == "Recovered")
        #expect(try await repository.fetchProject(id: project.id) == project)
        settings.settings.autosaveEnabled = true
        try await Task.sleep(for: .milliseconds(1300))
        #expect(editor.saveState == .saved)
        #expect(try await recovery.fetchRecovery(projectID: project.id) == nil)
        #expect(try await repository.fetchProject(id: project.id)?.codeName == "Recovered")
    }
}
