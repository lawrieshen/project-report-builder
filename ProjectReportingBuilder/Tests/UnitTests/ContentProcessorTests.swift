import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct ContentProcessorTests {
    @Test func labelledNotesProduceOptionalSuggestions() async throws {
        let result = try await ContentProcessor().process(text: """
        Project: Titan
        Line of Business: Camera
        Health: Amber
        Milestone: DVT
        Deadline: 2026-09-30
        Summary Type: blocker
        Summary: Camera latency remains high.
        Lead EPM: Jane Smith
        Project DRI: Alex
        """)
        #expect(result.codeName == "Titan")
        #expect(result.lineOfBusiness == "Camera")
        #expect(result.ragStatus == .amber)
        #expect(result.milestonePhase == "DVT")
        #expect(result.milestoneDeadline != nil)
        #expect(result.summaryType == .blocker)
        #expect(result.summaryMessage == "Camera latency remains high.")
        #expect(result.leadEPMName == "Jane Smith")
        #expect(result.projectDRIName == "Alex")
    }

    @Test func unrecognizedAndInvalidValuesAreNotGuessed() async throws {
        let result = try await ContentProcessor().process(text: """
        The project may be late next month.
        Health: purple
        Deadline: 2026-02-30
        Summary Type: anything
        Summary:
        """)
        #expect(result.isEmpty)
    }
}

actor ControlledContentProcessor: ContentProcessing {
    private var continuation: CheckedContinuation<ReportContentSuggestions, any Error>?
    var started: Bool { continuation != nil }
    func process(text: String) async throws -> ReportContentSuggestions {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish(failing: Bool = false) {
        if failing { continuation?.resume(throwing: AssetError.unreadableImage) }
        else { continuation?.resume(returning: ReportContentSuggestions(summaryMessage: "Old suggestion")) }
        continuation = nil
    }
}

@MainActor
struct ContentInputViewModelTests {
    @Test func emptyAndSuccessfulProcessing() async {
        let model = ContentInputViewModel()
        model.rawText = "   "
        #expect(!model.canProcess)
        await model.processText()
        #expect(model.suggestions == nil)
        model.rawText = "Summary: New summary"
        await model.processText()
        #expect(model.suggestions?.summaryMessage == "New summary")
        model.rawText = "Unstructured notes"
        await model.processText()
        #expect(model.suggestions?.isEmpty == true)
    }

    @Test func staleResultsAndFailuresAreHandled() async {
        let processor = ControlledContentProcessor()
        let model = ContentInputViewModel(processor: processor)
        model.rawText = "Original"
        let task = Task { await model.processText() }
        while !(await processor.started) { await Task.yield() }
        #expect(model.isProcessing)
        model.rawText = "Updated"
        await processor.finish()
        await task.value
        #expect(model.suggestions == nil)
        #expect(!model.isProcessing)
        let retry = Task { await model.processText() }
        while !(await processor.started) { await Task.yield() }
        await processor.finish(failing: true)
        await retry.value
        #expect(model.processingError != nil)
        #expect(model.rawText == "Updated")
        #expect(model.canProcess)
    }
}
