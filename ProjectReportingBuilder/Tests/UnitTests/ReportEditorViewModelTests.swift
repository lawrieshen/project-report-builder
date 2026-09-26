import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct ReportEditorViewModelTests {
    private func report() -> ProjectReport {
        ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                      status: .active, createdAt: .distantPast, updatedAt: .distantPast)
    }

    @Test func openingCardlessReportDoesNotWrite() async throws {
        let original = report()
        let repository = WorkspaceTestRepository(project: original)
        let model = ReportEditorViewModel(projectID: original.id, repository: repository)
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.project?.card != nil)
        #expect(!model.isDirty)
        #expect(!model.canSave)
        #expect(repository.saveCount == 0)
        #expect(repository.project?.card == nil)
        #expect(await model.save())
        #expect(repository.saveCount == 0)
        model.draft?.codeName = "Updated"
        await model.load()
        #expect(model.draft?.codeName == "Updated")
        #expect(model.isDirty)
        await model.discardChanges()
        #expect(!model.isDirty)
        #expect(model.draft?.codeName == "Titan")
        #expect(repository.saveCount == 0)
    }

    @Test func repeatedSavesKeepOneCardAndMetadata() async throws {
        let original = report()
        let repository = WorkspaceTestRepository(project: original)
        let model = ReportEditorViewModel(projectID: original.id, repository: repository)
        await model.load()
        let cardID = try #require(model.project?.card?.id)
        model.draft?.summaryMessage = "First"
        #expect(await model.save())
        #expect(!model.isDirty)
        model.draft?.summaryMessage = "Second"
        #expect(await model.save())
        #expect(repository.saveCount == 2)
        #expect(repository.project?.card?.id == cardID)
        #expect(repository.project?.card?.summary.message == "Second")
        #expect(repository.project?.createdAt == original.createdAt)
        #expect(repository.project?.updatedAt != original.updatedAt)
        let reopened = ReportEditorViewModel(projectID: original.id, repository: repository)
        await reopened.load()
        #expect(reopened.draft?.summaryMessage == "Second")
        #expect(reopened.project?.card?.id == cardID)
        #expect(!reopened.isDirty)
    }

    @Test func failuresPreserveDraftAndCanRetry() async {
        let original = report()
        let repository = WorkspaceTestRepository(project: original)
        repository.failLoad = true
        let model = ReportEditorViewModel(projectID: original.id, repository: repository)
        await model.load()
        #expect(model.loadError != nil)
        #expect(!model.isLoading)
        repository.failLoad = false
        await model.retry()
        #expect(model.loadError == nil)
        model.draft?.codeName = "Updated"
        model.draft?.summaryMessage = "Keep all my edits"
        let edited = model.draft
        repository.failSave = true
        #expect(await model.save() == false)
        #expect(model.draft == edited)
        #expect(model.isDirty)
        #expect(model.saveError != nil)
        #expect(!model.isSaving)
        #expect(repository.project == original)
        repository.failSave = false
        #expect(await model.save())
        #expect(!model.isDirty)
        #expect(model.saveError == nil)
    }

    @Test func revertingFailedEditsClearsStaleSaveError() async {
        let original = report()
        let repository = WorkspaceTestRepository(project: original)
        let model = ReportEditorViewModel(projectID: original.id, repository: repository)
        await model.load()
        repository.failSave = true
        model.draft?.codeName = "Changed"
        #expect(await model.save() == false)
        #expect(model.saveState == .failed("Save failed"))
        model.draft?.codeName = original.codeName
        #expect(model.saveError == nil)
        #expect(model.saveState == .saved)
        #expect(repository.saveCount == 0)
    }

    @Test func missingAndInvalidReportsDoNotSave() async {
        let missing = ReportEditorViewModel(projectID: UUID(), repository: WorkspaceTestRepository(project: nil))
        await missing.load()
        #expect(missing.hasLoaded && missing.project == nil && missing.loadError == nil)
        #expect(await missing.save() == false)
        let original = report()
        let repository = WorkspaceTestRepository(project: original)
        let model = ReportEditorViewModel(projectID: original.id, repository: repository)
        await model.load()
        model.draft?.codeName = " "
        #expect(!model.canSave)
        #expect(await model.save() == false)
        #expect(repository.saveCount == 0)
    }
}

@MainActor
final class WorkspaceTestRepository: ProjectRepository {
    var project: ProjectReport?
    var failLoad = false
    var failSave = false
    var saveCount = 0
    enum Failure: Error { case unavailable }
    init(project: ProjectReport?) { self.project = project }
    func fetchProjects() async throws -> [ProjectReport] { project.map { [$0] } ?? [] }
    func fetchProject(id: UUID) async throws -> ProjectReport? {
        if failLoad { throw Failure.unavailable }
        return project?.id == id ? project : nil
    }
    func save(_ project: ProjectReport) async throws {
        if failSave { throw Failure.unavailable }
        saveCount += 1
        self.project = project
    }
    func delete(_ project: ProjectReport) async throws { self.project = nil }
}
