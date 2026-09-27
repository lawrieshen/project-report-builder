import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct ComposerEditorIntegrationTests {
    @Test func applyEntersAutosaveAndUndoKeepsLaterEdits() async throws {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone",
                                    status: .active, createdAt: .now, updatedAt: .now)
        let repository = WorkspaceTestRepository(project: project)
        var preferences = AppSettings.default
        preferences.autosaveDelay = .seconds1
        let settings = AppSettingsStore(repository: MemorySettingsRepository(preferences))
        let editor = ReportEditorViewModel(projectID: project.id, repository: repository, settings: settings)
        await editor.load()
        let draft = try #require(editor.draft)
        let session = UUID()
        let composer = ReportComposerViewModel(draft: draft, reportID: project.id,
            accountSessionID: session, service: EditorComposerFake())
        await composer.send("Draft")
        try await Task.sleep(for: .milliseconds(1200))
        #expect(repository.saveCount == 0)
        #expect(editor.draft == draft)
        #expect(editor.applyComposition(composer, accountSessionID: session, acceptUnfinishedGoal: true))
        try await Task.sleep(for: .milliseconds(1300))
        #expect(repository.saveCount == 1)
        #expect(repository.project?.card?.summary.message == "Proposed summary")
        #expect(editor.saveState == .saved)
        editor.draft?.codeName = "Later title"
        #expect(editor.undoComposition(composer, accountSessionID: session))
        #expect(editor.draft?.codeName == "Later title")
        #expect(editor.draft?.summaryMessage == draft.summaryMessage)
        editor.setAutosavePaused(true)
    }

    @Test func conflictingCloudSaveBlocksApplyAndKeepsCandidate() async throws {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Mac",
                                    status: .active, createdAt: .now, updatedAt: .now)
        let repository = WorkspaceTestRepository(project: project)
        let editor = ReportEditorViewModel(projectID: project.id, repository: repository)
        await editor.load()
        editor.draft?.codeName = "Edited"
        repository.conflict = true
        #expect(await editor.save() == false)
        let draft = try #require(editor.draft)
        let session = UUID()
        let composer = ReportComposerViewModel(draft: draft, reportID: project.id,
            accountSessionID: session, service: EditorComposerFake())
        await composer.send("Draft")
        #expect(!editor.canApplyComposition)
        #expect(!editor.applyComposition(composer, accountSessionID: session, acceptUnfinishedGoal: true))
        #expect(editor.draft == draft)
        #expect(composer.candidate.summaryMessage == "Proposed summary")
    }
}

private struct EditorComposerFake: ReportComposing {
    func compose(_ request: CompositionRequest) async throws -> CompositionResponse {
        CompositionResponse(requestID: request.requestID, baseDraftVersion: request.baseDraftVersion,
            candidateVersion: request.candidateVersion, goalID: request.goal.id, goalRevision: request.goal.revision,
            proposal: .init(assistantMessage: "Review", clarifyingQuestions: [],
                proposedChanges: [.init(field: .summaryMessage, operation: .set, value: "Proposed summary")],
                metricChanges: [], warnings: [], semanticFindings: []), remainingDailyRequests: 19)
    }
}
