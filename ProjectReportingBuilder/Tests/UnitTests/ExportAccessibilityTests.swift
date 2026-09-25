import Testing
@testable import Project_Report_Builder

@MainActor
struct ExportAccessibilityTests {
    @Test func issuesRequireConfirmationBeforeRenderingAndCanBeReviewed() async {
        let renderer = ExportRendererSpy(), destination = ExportDestinationSpy()
        let model = ExportViewModel(renderer: renderer, clipboard: destination, fileExporter: destination, sharing: destination)
        var draft = ReportExportRendererTests.draft()
        draft.codeName = ""
        await model.request(.save, model: ReportPreviewModel(draft: draft), validation: AccessibilityValidationModel(draft: draft), appearance: .light)
        #expect(model.requiresConfirmation && renderer.models.isEmpty)
        #expect(model.accessibilityReport?.isValid == false)
        model.cancelPendingExport()
        #expect(!model.requiresConfirmation && destination.saved == nil)
        draft.codeName = "Fixed unsaved name"
        await model.request(.save, model: ReportPreviewModel(draft: draft), validation: AccessibilityValidationModel(draft: draft), appearance: .light)
        #expect(!model.requiresConfirmation && model.accessibilityReport?.isValid == true)
        #expect(renderer.models.last?.codeName == "Fixed unsaved name")
    }

    @Test func exportAnywayUsesTheCheckedSnapshotOnlyOnce() async {
        let renderer = ExportRendererSpy(), destination = ExportDestinationSpy()
        let model = ExportViewModel(renderer: renderer, clipboard: destination, fileExporter: destination, sharing: destination)
        var draft = ReportExportRendererTests.draft()
        draft.codeName = ""
        draft.summaryMessage = "Checked snapshot"
        await model.request(.copy, model: ReportPreviewModel(draft: draft), validation: AccessibilityValidationModel(draft: draft), appearance: .dark)
        draft.summaryMessage = "Later change"
        await model.exportAnyway()
        await model.exportAnyway()
        #expect(renderer.models.count == 1 && renderer.models.first?.summaryMessage == "Checked snapshot")
        #expect(renderer.options.first?.appearance == .dark)
        #expect(model.state == .success)
    }
}
