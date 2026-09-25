import Foundation
import Observation

enum ExportAction { case copy, save, share }
enum ExportState { case idle, rendering, saving, sharing, success, failure }

@MainActor
@Observable
final class ExportViewModel {
    var selectedFormat: ExportFormat = .png
    var imageScale: ExportImageScale = .standard
    var background: ExportBackground = .white
    private(set) var state: ExportState = .idle
    private(set) var errorMessage: String?
    private(set) var successMessage: String?
    private(set) var lastAction: ExportAction?
    private(set) var accessibilityReport: AccessibilityReport?
    private(set) var isCheckingAccessibility = false
    private var pendingExport: PendingExport?
    private let checker: any AccessibilityChecking

    private struct PendingExport {
        let action: ExportAction
        let model: ReportPreviewModel
        let appearance: ExportAppearance
    }

    var requiresConfirmation: Bool { pendingExport != nil }
    var isBusy: Bool { isExporting || isCheckingAccessibility }
    private let renderer: any ReportExportRendering
    private let clipboard: any ClipboardWriting
    private let fileExporter: any FileExporting
    private let sharing: any ReportSharing

    init(renderer: any ReportExportRendering, clipboard: any ClipboardWriting,
         fileExporter: any FileExporting, sharing: any ReportSharing,
         checker: any AccessibilityChecking = AccessibilityChecker()) {
        self.checker = checker
        self.renderer = renderer
        self.clipboard = clipboard
        self.fileExporter = fileExporter
        self.sharing = sharing
    }

    var isExporting: Bool { state == .rendering || state == .saving || state == .sharing }
    var progressMessage: String {
        switch state {
        case .saving: return "Choose where to save the report…"
        case .sharing: return "Opening sharing…"
        default: return "Generating report…"
        }
    }

    /// Recheck the same unsaved snapshot before every output action.
    func request(_ action: ExportAction, model: ReportPreviewModel,
                 validation: AccessibilityValidationModel, appearance: ExportAppearance) async {
        guard !isBusy, !requiresConfirmation else { return }
        errorMessage = nil
        successMessage = nil
        isCheckingAccessibility = true
        defer { isCheckingAccessibility = false }
        let report = await checker.validate(model: validation)
        guard !Task.isCancelled else { return }
        accessibilityReport = report
        if report.isValid {
            await perform(action, model: model, appearance: appearance)
        } else {
            pendingExport = PendingExport(action: action, model: model, appearance: appearance)
        }
    }

    func exportAnyway() async {
        guard !isBusy, let pendingExport else { return }
        self.pendingExport = nil
        await perform(pendingExport.action, model: pendingExport.model, appearance: pendingExport.appearance)
    }

    func cancelPendingExport() { pendingExport = nil }

    /// Export one immutable snapshot without accessing a project repository or editor.
    func perform(_ action: ExportAction, model: ReportPreviewModel, appearance: ExportAppearance) async {
        guard !isExporting else { return }
        lastAction = action
        errorMessage = nil
        successMessage = nil
        state = .rendering
        let options = ExportOptions(format: action == .copy ? .png : selectedFormat,
                                    imageScale: imageScale, background: background, appearance: appearance, date: .now)
        await Task.yield()
        do {
            try Task.checkCancellation()
            let result = try await renderer.render(model: model, options: options)
            try Task.checkCancellation()
            switch action {
            case .copy:
                try clipboard.writePNG(result.data)
                successMessage = "Copied report to clipboard"
            case .save:
                state = .saving
                guard let url = try await fileExporter.save(result: result) else {
                    state = .idle
                    return
                }
                successMessage = "Saved \(url.lastPathComponent)"
            case .share:
                state = .sharing
                try sharing.share(result: result)
                successMessage = "Share menu opened"
            }
            state = .success
        } catch is CancellationError {
            state = .idle
        } catch {
            let context = state == .saving ? "Unable to save report" : "Unable to export report"
            errorMessage = "\(context): \(error.localizedDescription)"
            state = .failure
        }
    }
}
