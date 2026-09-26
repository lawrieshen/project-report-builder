import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct AccessibilityTests {
    private func draft() -> ReportEditorDraft {
        ReportEditorDraft(project: ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone",
                                                 status: .active, createdAt: .now, updatedAt: .now))
    }

    @Test func optionalSectionsAreNotRequiredAndCanonicalStylesPass() async {
        let model = AccessibilityValidationModel(draft: draft())
        #expect(model.visibleSections == [.identity])
        let result = await AccessibilityChecker().validate(model: model)
        #expect(result.isValid)
    }

    @Test func whitespaceAltTextIsAnErrorForEachImageAndFixRemovesIt() async {
        var draft = draft()
        draft.assets = [ImageAsset(id: UUID(), fileName: "A.png", localReference: "a", altText: " \n"),
                        ImageAsset(id: UUID(), fileName: "B.png", localReference: "b", altText: "Diagram")]
        let result = await AccessibilityChecker().validate(model: AccessibilityValidationModel(draft: draft))
        #expect(result.issues.count == 1)
        #expect(result.issues.first?.type == .missingAltText)
        #expect(result.issues.first?.severity == .error)
        #expect(result.issues.first?.section == .supportingContent)
        #expect(result.issues.first?.message.contains("A.png") == true)
        draft.assets[0].altText = "Camera setup"
        let fixed = await AccessibilityChecker().validate(model: AccessibilityValidationModel(draft: draft))
        #expect(fixed.isValid)
    }

    @Test func statusWithoutTextIsDetectedButAbsentStatusIsAllowed() async {
        var model = AccessibilityValidationModel(draft: draft())
        model.statusLabel = " \n"
        model.metricStatusLabels = [""]
        let result = await AccessibilityChecker().validate(model: model)
        #expect(result.issues.filter { $0.type == .colorOnlyStatus }.count == 2)
        for status in RAGStatus.allCases {
            var draft = draft()
            draft.ragStatus = status
            let valid = await AccessibilityChecker().validate(model: AccessibilityValidationModel(draft: draft))
            #expect(valid.isValid)
        }
    }

    @Test func incompleteMetricAndEmptyProjectKeepTheirMissingLabels() async {
        var draft = draft()
        draft.codeName = " "
        draft.metrics = [EngineeringMetricDraft()]
        var model = AccessibilityValidationModel(draft: draft)
        model.roleLabels = [" "]
        let result = await AccessibilityChecker().validate(model: model)
        #expect(result.issues.filter { $0.type == .emptyLabel }.map(\.section) == [.identity, .metrics, .accountability])
    }

    @Test func contrastUsesKnownReferenceRatiosAndBothAppearances() async {
        #expect(abs(AccessibilityChecker.contrast(ReportRGB(0), ReportRGB(1)) - 21) < 0.0001)
        #expect(AccessibilityChecker.contrast(ReportRGB(0.5), ReportRGB(0.5)) == 1)
        #expect(AccessibilityChecker.contrast(ReportRGB(0.46), ReportRGB(1)) > 4.5)
        #expect(AccessibilityChecker.contrast(ReportRGB(0.47), ReportRGB(1)) < 4.5)
        var style = ReportAccessibilityStyle.canonical
        style.dark.secondary = style.dark.background
        style.light.primary = style.light.background
        let report = await AccessibilityChecker(style: style).validate(model: AccessibilityValidationModel(draft: draft()))
        let contrast = report.issues.filter { $0.type == .lowContrast }
        #expect(contrast.contains { $0.message.contains("Light") })
        #expect(contrast.contains { $0.message.contains("Dark") })
    }

    @Test func typographyThresholdsAndInvalidTokensAreChecked() async {
        var style = ReportAccessibilityStyle.canonical
        style.bodySize = 13
        style.captionSize = 11
        style.light.secondary = ReportRGB(.nan)
        let result = await AccessibilityChecker(style: style).validate(model: AccessibilityValidationModel(draft: draft()))
        #expect(result.issues.filter { $0.type == .smallText }.count == 2)
        #expect(result.issues.contains { $0.type == .lowContrast })
    }

    @Test func onlyVisibleSectionsRequireHeadingMarkers() async {
        var draft = draft()
        var style = ReportAccessibilityStyle.canonical
        style.headingSections.remove(.summary)
        let empty = await AccessibilityChecker(style: style).validate(model: AccessibilityValidationModel(draft: draft))
        #expect(empty.isValid)
        draft.summaryMessage = "Latest update"
        let shown = await AccessibilityChecker(style: style).validate(model: AccessibilityValidationModel(draft: draft))
        #expect(shown.issues.first?.type == .missingHeading)
        #expect(shown.issues.first?.section == .summary)
        style.sectionLevel = 4
        let hierarchy = await AccessibilityChecker(style: style).validate(model: AccessibilityValidationModel(draft: draft))
        #expect(!hierarchy.isValid)
    }

    @Test func validationAndRecheckReadUnsavedDraftWithoutSaving() async throws {
        let original = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone",
                                     status: .active, createdAt: .now, updatedAt: .now)
        let repository = WorkspaceTestRepository(project: original)
        let editor = ReportEditorViewModel(projectID: original.id, repository: repository)
        await editor.load()
        let viewModel = AccessibilityViewModel()
        await viewModel.validate(model: AccessibilityValidationModel(draft: try #require(editor.draft)))
        #expect(viewModel.report?.isValid == true)
        #expect(!editor.isDirty)
        editor.draft?.assets = [ImageAsset(id: UUID(), fileName: "A.png", localReference: "a")]
        let before = editor.draft
        await viewModel.validate(model: AccessibilityValidationModel(draft: try #require(editor.draft)))
        #expect(viewModel.report?.issues.first?.type == .missingAltText)
        #expect(editor.draft == before)
        editor.draft?.assets[0].altText = "Diagram"
        let fixed = editor.draft
        await viewModel.validate(model: AccessibilityValidationModel(draft: try #require(editor.draft)))
        #expect(viewModel.report?.isValid == true)
        #expect(!viewModel.isChecking)
        #expect(editor.draft == fixed && editor.isDirty)
        #expect(repository.saveCount == 0)
        #expect(repository.project == original)
    }

    @Test func cancelledCheckDoesNotPublishAResult() async {
        let viewModel = AccessibilityViewModel(checker: SuspendedChecker())
        let model = AccessibilityValidationModel(draft: draft())
        let task = Task { await viewModel.validate(model: model) }
        await Task.yield()
        task.cancel()
        await task.value
        #expect(viewModel.report == nil)
        #expect(!viewModel.isChecking)
    }
}

private struct SuspendedChecker: AccessibilityChecking {
    func validate(model: AccessibilityValidationModel) async -> AccessibilityReport {
        try? await Task.sleep(for: .seconds(1))
        return AccessibilityReport(issues: [])
    }
}
