import Foundation
import CoreGraphics
import Testing
@testable import Project_Report_Builder

@MainActor
struct ReportPreviewTests {
    private func report() -> ProjectReport {
        ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                      status: .active, createdAt: .distantPast, updatedAt: .distantPast)
    }

    @Test func previewUsesUnsavedDraftWithoutSavingAndTracksDiscard() async throws {
        let original = report()
        let repository = WorkspaceTestRepository(project: original)
        let editor = ReportEditorViewModel(projectID: original.id, repository: repository)
        #expect(editor.previewModel == nil)
        await editor.load()
        editor.draft?.summaryMessage = "Saved A"
        #expect(await editor.save())
        let saved = repository.project
        let saveCount = repository.saveCount
        editor.draft?.summaryMessage = "Unsaved B"
        editor.draft?.codeName = "Updated"
        #expect(editor.previewModel?.summaryMessage == "Unsaved B")
        #expect(editor.previewModel?.codeName == "Updated")
        let draft = editor.draft
        let controls = LivePreviewViewModel()
        controls.zoomIn()
        controls.appearance = .dark
        #expect(editor.draft == draft)
        #expect(repository.project == saved)
        #expect(repository.saveCount == saveCount)
        #expect(editor.isDirty)
        await editor.discardChanges()
        #expect(editor.previewModel?.summaryMessage == "Saved A")
        #expect(!editor.isDirty)
    }

    @Test func mapsAllFieldsAndPreservesMetricAndAssetOrder() throws {
        var draft = ReportEditorDraft(project: report())
        draft.ragStatus = .amber
        draft.milestonePhase = "DVT"
        draft.milestoneDeadline = Date(timeIntervalSince1970: 100)
        draft.summaryType = .ask
        draft.summaryMessage = "Need support"
        draft.leadEPMName = "Jane"
        draft.projectDRIName = "Alex"
        var first = EngineeringMetricDraft()
        first.name = "Latency"
        first.currentValueText = "120"
        first.hasTarget = true
        first.targetValueText = "100"
        var second = EngineeringMetricDraft()
        second.name = "Bugs"
        second.currentValueText = "2"
        draft.metrics = [first, second]
        draft.assets = [ImageAsset(id: UUID(), fileName: "A.png", localReference: "a"),
                        ImageAsset(id: UUID(), fileName: "B.png", localReference: "b", altText: "Second")]
        let model = ReportPreviewModel(draft: draft)
        #expect(model.codeName == draft.codeName)
        #expect(model.lineOfBusiness == draft.lineOfBusiness)
        #expect(model.ragStatus == .amber)
        #expect(model.milestonePhase == "DVT")
        #expect(model.milestoneDeadline == draft.milestoneDeadline)
        #expect(model.summaryType == .ask)
        #expect(model.summaryMessage == "Need support")
        #expect(model.leadEPMName == "Jane")
        #expect(model.projectDRIName == "Alex")
        #expect(model.metrics.map(\.id) == [first.id, second.id])
        #expect(model.metrics.first?.metric?.targetStatus == .missed)
        #expect(model.assets == draft.assets)
        #expect(model.assets[1].altText == "Second")
    }

    @Test func incompleteContentAndInvalidMetricsStaySafe() {
        var draft = ReportEditorDraft(project: report())
        draft.codeName = " "
        draft.lineOfBusiness = ""
        draft.leadEPMName = "  "
        let empty = ReportPreviewModel(draft: draft)
        #expect(empty.codeName.isEmpty)
        #expect(empty.ragStatus == nil)
        #expect(empty.milestonePhase == nil)
        #expect(empty.milestoneDeadline == nil)
        #expect(empty.metrics.isEmpty && empty.assets.isEmpty)
        #expect(empty.summaryMessage.isEmpty)
        #expect(empty.leadEPMName == nil && empty.projectDRIName == nil)
        var invalid = EngineeringMetricDraft()
        invalid.name = "Partial metric"
        invalid.currentValueText = "-"
        draft.metrics = [invalid]
        let partial = ReportPreviewModel(draft: draft)
        #expect(partial.metrics.count == 1)
        #expect(partial.metrics[0].metric == nil)
        #expect(partial.metrics[0].validationMessage != nil)
        #expect(draft.metrics[0].currentValueText == "-")
    }

    @Test func countdownUsesCalendarDaysAcrossDaylightSaving() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        let past = try #require(calendar.date(byAdding: .day, value: -3, to: today))
        #expect(MilestoneCountdown.text(deadline: tomorrow, now: today, calendar: calendar) == "1 day remaining")
        #expect(MilestoneCountdown.text(deadline: today, now: today, calendar: calendar) == "Due today")
        #expect(MilestoneCountdown.text(deadline: past, now: today, calendar: calendar) == "3 days overdue")
    }

    @Test func zoomBoundsActualSizeAndFit() {
        let model = LivePreviewViewModel()
        for _ in 0..<30 { model.zoomIn() }
        #expect(model.zoom == 2)
        for _ in 0..<30 { model.zoomOut() }
        #expect(model.zoom == 0.5)
        model.resetZoom()
        #expect(model.zoom == 1 && !model.isFitting)
        model.fit()
        #expect(model.displayedZoom(available: CGSize(width: 360, height: 300),
                                   content: CGSize(width: 720, height: 1200)) == 0.25)
        #expect(model.displayedZoom(available: CGSize(width: 900, height: 900),
                                   content: CGSize(width: 720, height: 400)) == 1)
        #expect(model.displayedZoom(available: .zero, content: .zero) == 1)
        model.zoomIn(from: 0.25)
        #expect(model.zoom == 0.5 && !model.isFitting)
    }
}
