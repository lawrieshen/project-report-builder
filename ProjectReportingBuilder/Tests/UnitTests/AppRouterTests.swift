import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct AppRouterTests {
    private func report() -> ProjectReport {
        ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                      status: .draft, createdAt: .now, updatedAt: .now)
    }

    @Test func cleanNavigationAndDirtyCancel() async throws {
        let project = report()
        let repository = WorkspaceTestRepository(project: project)
        let router = AppRouter(repository: repository)
        router.openProject(id: project.id)
        #expect(router.route == .reportEditor(projectID: project.id))
        let editor = try #require(router.editor)
        await editor.load()
        editor.draft?.codeName = "Edited"
        router.showProjects()
        #expect(router.showingLeaveConfirmation)
        #expect(router.editor === editor)
        router.cancelNavigation()
        #expect(!router.showingLeaveConfirmation)
        #expect(editor.draft?.codeName == "Edited")
        router.newProject()
        #expect(!router.showingNewProject)
        router.discardAndLeave()
        #expect(router.showingNewProject)
        #expect(router.route == nil)
        #expect(repository.saveCount == 0)
        router.showProjects()
        #expect(!router.showingNewProject)
    }

    @Test func failedSaveOrValidationKeepsWorkspaceOpen() async throws {
        let project = report()
        let repository = WorkspaceTestRepository(project: project)
        let router = AppRouter(repository: repository)
        router.openProject(id: project.id)
        let editor = try #require(router.editor)
        await editor.load()
        editor.draft?.codeName = " "
        router.showProjects()
        await router.saveAndLeave()
        #expect(router.editor === editor)
        #expect(editor.isDirty)
        editor.draft?.codeName = "Updated"
        repository.failSave = true
        router.showProjects()
        await router.saveAndLeave()
        #expect(router.editor === editor)
        #expect(editor.saveError != nil)
        repository.failSave = false
        router.showProjects()
        await router.saveAndLeave()
        #expect(router.route == nil)
        #expect(repository.project?.codeName == "Updated")
    }

    @Test func anotherProjectAlsoRequiresConfirmation() async throws {
        let project = report()
        let router = AppRouter(repository: WorkspaceTestRepository(project: project))
        router.openProject(id: project.id)
        let editor = try #require(router.editor)
        await editor.load()
        editor.draft?.summaryMessage = "Unsaved"
        let otherID = UUID()
        router.openProject(id: otherID)
        #expect(router.route == .reportEditor(projectID: project.id))
        router.discardAndLeave()
        #expect(router.route == .reportEditor(projectID: otherID))
        await router.editor?.load()
        #expect(router.editor?.project == nil)
    }
}
