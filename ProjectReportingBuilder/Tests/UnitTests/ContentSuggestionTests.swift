import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct ContentSuggestionTests {
    @Test func unselectedExistingSummaryIsNeverOverwritten() async throws {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                    status: .active, template: .technical, createdAt: .now, updatedAt: .now)
        let repository = WorkspaceTestRepository(project: project)
        let model = ReportEditorViewModel(projectID: project.id, repository: repository)
        await model.load()
        model.draft?.summaryMessage = "Keep existing summary"
        #expect(await model.save())
        let before = model.draft
        let suggestions = try await ContentProcessor().process(text: """
        Project: Changed
        Summary: Replace existing summary
        Health: Amber
        """)
        #expect(model.draft == before)
        var selection = ContentSuggestionSelection(suggestions: suggestions, draft: try #require(model.draft))
        #expect(!selection.fields.contains(.summary))
        #expect(!selection.fields.contains(.codeName))
        #expect(selection.fields.contains(.health))
        model.applyContentSuggestions(suggestions, selection: selection)
        #expect(model.draft?.summaryMessage == "Keep existing summary")
        #expect(model.draft?.codeName == "Titan")
        #expect(model.draft?.ragStatus == .amber)
        #expect(model.isDirty)
        #expect(repository.project?.card?.health.ragStatus == nil)
        selection.fields = [.summary, .deadline]
        model.applyContentSuggestions(suggestions, selection: selection)
        #expect(model.draft?.summaryMessage == "Replace existing summary")
        #expect(model.draft?.milestoneDeadline == nil)
        repository.failSave = true
        let changed = model.draft
        #expect(await model.save() == false)
        #expect(model.draft == changed)
        model.discardChanges()
        #expect(model.draft == before)
        #expect(repository.project?.template == .technical)
    }

    @Test func selectedFieldsApplyWithoutClearingMissingSuggestions() async throws {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                    status: .draft, createdAt: .now, updatedAt: .now)
        let model = ReportEditorViewModel(projectID: project.id, repository: WorkspaceTestRepository(project: project))
        await model.load()
        model.draft?.projectDRIName = "Existing DRI"
        let suggestions = ReportContentSuggestions(lineOfBusiness: "Platform", milestonePhase: "DVT",
            milestoneDeadline: Date(timeIntervalSince1970: 100), summaryType: .ask, leadEPMName: "Jane")
        var selection = ContentSuggestionSelection()
        selection.fields = Set(ContentSuggestionField.allCases)
        model.applyContentSuggestions(suggestions, selection: selection)
        #expect(model.draft?.codeName == "Titan")
        #expect(model.draft?.lineOfBusiness == "Platform")
        #expect(model.draft?.milestonePhase == "DVT")
        #expect(model.draft?.milestoneDeadline == suggestions.milestoneDeadline)
        #expect(model.draft?.summaryType == .ask)
        #expect(model.draft?.leadEPMName == "Jane")
        #expect(model.draft?.projectDRIName == "Existing DRI")
        #expect(await model.save())
    }
}
