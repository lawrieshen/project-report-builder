import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct RecoveryPreferencesTests {
    private func project() -> ProjectReport {
        ProjectReport(id: UUID(), codeName: "Original", lineOfBusiness: "iPhone",
                      status: .active, createdAt: .now, updatedAt: .now)
    }

    @Test func hiddenPromptRestoresWithoutDiscardingOrSaving() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ProjectFileStore(storage: ApplicationStorage(root: root))
        let repository = LocalProjectRepository(store: store)
        let recovery = LocalDraftRecoveryRepository(store: store)
        let report = project()
        try await repository.save(report)
        var draft = ReportEditorDraft(project: report)
        draft.codeName = "Recovered"
        try await recovery.saveRecovery(RecoverySnapshot(projectID: report.id, baseUpdatedAt: report.updatedAt,
                                                         capturedAt: .now, draft: draft))
        var preferences = AppSettings.default
        preferences.autosaveEnabled = false
        preferences.showRecoveryPrompt = false
        let settings = AppSettingsStore(repository: MemorySettingsRepository(preferences))
        let editor = ReportEditorViewModel(projectID: report.id, repository: repository,
            recoveryRepository: recovery, recoveryDelay: .zero, settings: settings)
        await editor.load()
        #expect(editor.pendingRecovery == nil)
        #expect(editor.draft?.codeName == "Recovered")
        #expect(editor.isDirty)
        await editor.recoveryTask?.value
        #expect(try await repository.fetchProject(id: report.id) == report)
        #expect(try await recovery.fetchRecovery(projectID: report.id) != nil)
    }

    @Test func clearingCancelsPendingWritesAndPreservesCanonicalFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ApplicationStorage(root: root)
        let store = ProjectFileStore(storage: storage)
        let repository = LocalProjectRepository(store: store)
        let recovery = LocalDraftRecoveryRepository(store: store)
        let report = project()
        try await repository.save(report)
        let originalData = try Data(contentsOf: storage.projectFile(report.id))
        let asset = ImageAsset(id: UUID(), fileName: "image.png", localReference: "image.png", altText: "Image")
        try await store.writeAsset(Data([1, 2, 3]), asset: asset, projectID: report.id)
        var preferences = AppSettings.default
        preferences.autosaveDelay = .seconds1
        let settings = AppSettingsStore(repository: MemorySettingsRepository(preferences))
        let editor = ReportEditorViewModel(projectID: report.id, repository: repository,
            recoveryRepository: recovery, recoveryDelay: .seconds(1), settings: settings)
        await editor.load()
        editor.draft?.codeName = "Pending backup"
        let maintenance = RecoveryMaintenanceCoordinator()
        maintenance.participant = editor
        try await maintenance.clearRecovery(using: store)
        settings.settings.autosaveDelay = .seconds2
        settings.settings.autosaveDelay = .seconds1
        try await Task.sleep(for: .milliseconds(1300))
        #expect(try await recovery.fetchRecovery(projectID: report.id) == nil)
        #expect(try Data(contentsOf: storage.projectFile(report.id)) == originalData)
        #expect(try Data(contentsOf: storage.assets(report.id).appendingPathComponent("image.png")) == Data([1, 2, 3]))
        #expect(editor.draft?.codeName == "Pending backup")
        #expect(editor.isDirty)
        settings.settings.autosaveEnabled = false
        editor.draft?.codeName = "Next edit"
        await editor.recoveryTask?.value
        #expect(try await recovery.fetchRecovery(projectID: report.id)?.draft.codeName == "Next edit")
        #expect(try await store.information().recoveryCount == 1)
        try await maintenance.clearRecovery(using: store)
        #expect(try await store.information().recoveryCount == 0)
        #expect(try await repository.fetchProject(id: report.id) == report)
    }

    @Test func settingsChangeRestoresPendingPromptImmediately() async throws {
        let report = project()
        var draft = ReportEditorDraft(project: report)
        draft.codeName = "Restored"
        let recovery = FixedRecoveryRepository(snapshot: RecoverySnapshot(projectID: report.id,
            baseUpdatedAt: report.updatedAt, capturedAt: .now, draft: draft))
        var preferences = AppSettings.default
        preferences.autosaveEnabled = false
        let settings = AppSettingsStore(repository: MemorySettingsRepository(preferences))
        let editor = ReportEditorViewModel(projectID: report.id, repository: WorkspaceTestRepository(project: report),
            recoveryRepository: recovery, recoveryDelay: .zero, settings: settings)
        await editor.load()
        #expect(editor.pendingRecovery != nil)
        settings.settings.showRecoveryPrompt = false
        #expect(editor.pendingRecovery == nil)
        #expect(editor.draft?.codeName == "Restored")
        #expect(editor.isDirty)
        await editor.recoveryTask?.value
    }
}

private actor FixedRecoveryRepository: DraftRecoveryRepository {
    var snapshot: RecoverySnapshot?
    init(snapshot: RecoverySnapshot) { self.snapshot = snapshot }
    func fetchRecovery(projectID: UUID) async throws -> RecoverySnapshot? { snapshot }
    func saveRecovery(_ snapshot: RecoverySnapshot) async throws { self.snapshot = snapshot }
    func deleteRecovery(projectID: UUID) async throws { snapshot = nil }
}
