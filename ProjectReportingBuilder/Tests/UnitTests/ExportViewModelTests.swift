import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
final class ExportRendererSpy: ReportExportRendering {
    var models: [ReportPreviewModel] = []
    var options: [ExportOptions] = []
    var fails = false
    var suspends = false
    func render(model: ReportPreviewModel, options: ExportOptions) async throws -> ExportResult {
        self.models.append(model)
        self.options.append(options)
        if suspends { try await Task.sleep(for: .seconds(1)) }
        if fails { throw ExportError.renderingFailed }
        return ExportResult(data: Data(model.summaryMessage.utf8), fileName: "Titan." + options.format.rawValue, contentType: options.format)
    }
}

@MainActor
final class ExportDestinationSpy: ClipboardWriting, FileExporting, ReportSharing {
    var copied: Data?
    var saved: ExportResult?
    var shared: ExportResult?
    var cancelled = false
    var fails = false
    func writePNG(_ data: Data) throws {
        if fails { throw ExportError.clipboardFailed }
        copied = data
    }
    func save(result: ExportResult) async throws -> URL? {
        if fails { throw CocoaError(.fileWriteNoPermission) }
        saved = result
        return cancelled ? nil : URL(fileURLWithPath: "/tmp/" + result.fileName)
    }
    func share(result: ExportResult) throws {
        if fails { throw ExportError.sharingUnavailable }
        shared = result
    }
}

@MainActor
struct ExportViewModelTests {
    private func viewModel(_ renderer: ExportRendererSpy, _ destination: ExportDestinationSpy) -> ExportViewModel {
        ExportViewModel(renderer: renderer, clipboard: destination, fileExporter: destination, sharing: destination)
    }

    @Test func unsavedContentIsExportedWithoutSavingOrChangingDirtyState() async throws {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone", status: .active, createdAt: .now, updatedAt: .now)
        let repository = WorkspaceTestRepository(project: project)
        let editor = ReportEditorViewModel(projectID: project.id, repository: repository)
        await editor.load()
        let renderer = ExportRendererSpy(), destination = ExportDestinationSpy()
        let model = viewModel(renderer, destination)
        await model.perform(.copy, model: try #require(editor.previewModel), appearance: .light)
        #expect(!editor.isDirty && repository.saveCount == 0)
        editor.draft?.summaryMessage = "Unsaved B"
        let before = editor.draft
        model.selectedFormat = .html
        await model.perform(.copy, model: try #require(editor.previewModel), appearance: .dark)
        #expect(renderer.options.last?.format == .png)
        #expect(renderer.options.last?.appearance == .dark)
        #expect(renderer.models.last == editor.previewModel)
        #expect(destination.copied == Data("Unsaved B".utf8))
        #expect(editor.draft == before && editor.isDirty && repository.saveCount == 0)
        #expect(model.state == .success)
    }

    @Test func saveAndShareReceiveSelectedFormatAndCancellationIsNeutral() async {
        let renderer = ExportRendererSpy(), destination = ExportDestinationSpy()
        let model = viewModel(renderer, destination)
        let report = ReportPreviewModel(draft: ReportExportRendererTests.draft())
        model.selectedFormat = .html
        await model.perform(.save, model: report, appearance: .light)
        #expect(destination.saved?.contentType == .html)
        #expect(model.successMessage == "Saved Titan.html")
        destination.cancelled = true
        await model.perform(.save, model: report, appearance: .light)
        #expect(model.state == .idle && model.errorMessage == nil && model.successMessage == nil)
        await model.perform(.share, model: report, appearance: .light)
        #expect(destination.shared?.contentType == .html)
        #expect(model.successMessage == "Share menu opened")
    }

    @Test func failuresAreRecoverableAndDoNotReachDestinationsAfterRenderFailure() async {
        let renderer = ExportRendererSpy(), destination = ExportDestinationSpy()
        let model = viewModel(renderer, destination)
        let report = ReportPreviewModel(draft: ReportExportRendererTests.draft())
        renderer.fails = true
        await model.perform(.copy, model: report, appearance: .light)
        #expect(model.state == .failure && destination.copied == nil)
        renderer.fails = false
        for action in [ExportAction.copy, .save, .share] {
            destination.fails = true
            await model.perform(action, model: report, appearance: .light)
            #expect(model.errorMessage != nil && model.state == .failure)
            destination.fails = false
            await model.perform(action, model: report, appearance: .light)
            #expect(model.state == .success && model.errorMessage == nil)
        }
    }

    @Test func repeatedActionsAreIgnoredAndCancelledRenderingHasNoSideEffects() async {
        let renderer = ExportRendererSpy(), destination = ExportDestinationSpy()
        renderer.suspends = true
        let model = viewModel(renderer, destination)
        let report = ReportPreviewModel(draft: ReportExportRendererTests.draft())
        let task = Task { await model.perform(.copy, model: report, appearance: .light) }
        while !model.isExporting { await Task.yield() }
        await model.perform(.save, model: report, appearance: .light)
        task.cancel()
        await task.value
        #expect(renderer.models.count <= 1)
        #expect(destination.copied == nil && destination.saved == nil)
        #expect(model.state == .idle)
    }
}
