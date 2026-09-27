import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct AutosaveTests {
    private func fixture() async -> (ReportEditorViewModel, WorkspaceTestRepository, AppSettingsStore) {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone",
                                    status: .active, createdAt: .now, updatedAt: .now)
        let repository = WorkspaceTestRepository(project: project)
        var preferences = AppSettings.default
        preferences.autosaveDelay = .seconds1
        let settings = AppSettingsStore(repository: MemorySettingsRepository(preferences))
        let editor = ReportEditorViewModel(projectID: project.id, repository: repository, settings: settings)
        await editor.load()
        return (editor, repository, settings)
    }

    @Test func debounceSavesLatestDraftOnly() async throws {
        let (editor, repository, _) = await fixture()
        editor.draft?.summaryMessage = "First"
        try await Task.sleep(for: .milliseconds(600))
        editor.draft?.summaryMessage = "Latest"
        try await Task.sleep(for: .milliseconds(600))
        #expect(repository.saveCount == 0)
        try await Task.sleep(for: .milliseconds(700))
        #expect(repository.saveCount == 1)
        #expect(repository.project?.card?.summary.message == "Latest")
        #expect(!editor.isDirty)
        #expect(editor.saveState == .saved)
    }

    @Test func manualSaveAndDiscardCancelPendingSave() async throws {
        let (editor, repository, _) = await fixture()
        editor.draft?.codeName = "Saved"
        #expect(await editor.save())
        editor.draft?.codeName = "Discarded"
        #expect(await editor.discardChanges())
        try await Task.sleep(for: .milliseconds(1300))
        #expect(repository.saveCount == 1)
        #expect(repository.project?.codeName == "Saved")
    }

    @Test func disabledAndInvalidDraftsNeverAutosave() async throws {
        let (editor, repository, settings) = await fixture()
        editor.draft?.codeName = "Changed"
        settings.settings.autosaveEnabled = false
        try await Task.sleep(for: .milliseconds(1300))
        #expect(repository.saveCount == 0)
        editor.draft?.codeName = " "
        settings.settings.autosaveEnabled = true
        try await Task.sleep(for: .milliseconds(1300))
        #expect(repository.saveCount == 0)
        #expect(editor.isDirty)
        editor.draft?.codeName = "Valid"
        try await Task.sleep(for: .milliseconds(1300))
        #expect(repository.saveCount == 1)
    }

    @Test func failurePreservesDraftAndManualRetryWorks() async throws {
        let (editor, repository, _) = await fixture()
        repository.failSave = true
        editor.draft?.codeName = "Retained"
        try await Task.sleep(for: .milliseconds(1300))
        #expect(editor.saveError != nil)
        #expect(editor.saveState == .failed("Autosave failed"))
        #expect(editor.isDirty)
        repository.failSave = false
        try await Task.sleep(for: .milliseconds(1300))
        #expect(repository.saveCount == 0)
        #expect(await editor.save())
        #expect(repository.project?.codeName == "Retained")
    }

    @Test func conflictStopsAutosaveEvenAfterFurtherEdits() async throws {
        let (editor, repository, _) = await fixture()
        repository.conflict = true
        editor.draft?.codeName = "First"
        #expect(await editor.save() == false)
        #expect(editor.hasCloudConflict)
        repository.conflict = false
        editor.draft?.codeName = "Retained"
        try await Task.sleep(for: .milliseconds(1300))
        #expect(repository.saveCount == 0)
        #expect(!editor.canSave)
        #expect(editor.isDirty)
        await editor.reloadCloudVersion()
        #expect(!editor.hasCloudConflict)
        #expect(editor.draft?.codeName == "Titan")
    }

    @Test func navigationPauseAndDelayChangesReschedule() async throws {
        let (editor, repository, settings) = await fixture()
        editor.draft?.codeName = "Changed"
        editor.setAutosavePaused(true)
        try await Task.sleep(for: .milliseconds(1300))
        #expect(repository.saveCount == 0)
        settings.settings.autosaveDelay = .seconds5
        editor.setAutosavePaused(false)
        settings.settings.autosaveDelay = .seconds1
        try await Task.sleep(for: .milliseconds(1300))
        #expect(repository.saveCount == 1)
    }
}
