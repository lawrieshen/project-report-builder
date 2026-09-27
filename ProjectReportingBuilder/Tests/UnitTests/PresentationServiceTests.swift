import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct PresentationServiceTests {
    @Test func textImportUsesInjectedReader() async {
        let model = ContentInputViewModel(textReader: StubTextReader(fails: false))
        await model.importText(from: URL(fileURLWithPath: "/unused.txt"))
        #expect(model.rawText == "Imported notes")
        #expect(!model.isImportingText)
        #expect(model.importError == nil)
    }

    @Test func failedImportPreservesNotes() async {
        let model = ContentInputViewModel(textReader: StubTextReader(fails: true))
        model.rawText = "Keep these notes"
        await model.importText(from: URL(fileURLWithPath: "/unused.txt"))
        #expect(model.rawText == "Keep these notes")
        #expect(model.importError != nil)
        #expect(!model.isImportingText)
    }

    @Test func dismissedImportCannotReplaceNotes() async {
        let reader = ControlledTextReader()
        let model = ContentInputViewModel(textReader: reader)
        model.rawText = "Original"
        let task = Task { await model.importText(from: URL(fileURLWithPath: "/unused.txt")) }
        while !(await reader.started) { await Task.yield() }
        #expect(!model.canProcess)
        model.cancelPendingWork()
        await reader.finish()
        await task.value
        #expect(model.rawText == "Original")
        #expect(!model.isImportingText)
    }

    @Test func latestValidationWinsWhenChecksFinishOutOfOrder() async {
        let checker = ControlledValidationService()
        let viewModel = ReportValidationViewModel(checker: checker)
        let project = ProjectReport(id: UUID(), codeName: "Test", lineOfBusiness: "iPhone",
                                    status: .draft, createdAt: .now, updatedAt: .now)
        let model = ReportValidationModel(draft: ReportEditorDraft(project: project))
        let first = Task { await viewModel.validate(model: model) }
        while checker.requests.count < 1 { await Task.yield() }
        let second = Task { await viewModel.validate(model: model) }
        while checker.requests.count < 2 { await Task.yield() }
        checker.requests[1].resume(returning: ReportValidationReport(issues: []))
        await second.value
        #expect(viewModel.report?.isValid == true)
        checker.requests[0].resume(returning: ReportValidationReport(issues: [
            ReportValidationIssue(id: UUID(), type: .missingAltText, severity: .warning,
                                  title: "Old issue", message: "Old result", section: .supportingContent)
        ]))
        await first.value
        #expect(viewModel.report?.isValid == true)
        #expect(viewModel.report?.issues.isEmpty == true)
        #expect(!viewModel.isChecking)
    }
}

private struct StubTextReader: SourceTextReading {
    let fails: Bool
    func read(from url: URL) async throws -> String {
        if fails { throw TextImportError.invalidFile }
        return "Imported notes"
    }
}

private actor ControlledTextReader: SourceTextReading {
    var started = false
    private var continuation: CheckedContinuation<String, Never>?
    func read(from url: URL) async throws -> String {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started = true
        }
    }
    func finish() { continuation?.resume(returning: "Late notes"); continuation = nil }
}

@MainActor
private final class ControlledValidationService: ReportValidating {
    var requests: [CheckedContinuation<ReportValidationReport, Never>] = []
    func validate(model: ReportValidationModel) async -> ReportValidationReport {
        await withCheckedContinuation { requests.append($0) }
    }
}
