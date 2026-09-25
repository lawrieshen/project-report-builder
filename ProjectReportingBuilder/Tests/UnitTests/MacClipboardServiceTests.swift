import AppKit
import Testing
@testable import Project_Report_Builder

@MainActor
struct MacClipboardServiceTests {
    @Test func validPNGIsWrittenToAnIsolatedPasteboard() async throws {
        let pasteboard = NSPasteboard(name: .init("ExportTest-" + UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        let result = try await ReportExportRenderer { _ in throw ExportError.renderingFailed }
            .render(model: ReportPreviewModel(draft: ReportExportRendererTests.draft()), options: ExportOptions())
        try MacClipboardService(pasteboard: pasteboard).writePNG(result.data)
        #expect(pasteboard.data(forType: .png) == result.data)
    }

    @Test func invalidPNGDoesNotEraseExistingClipboardContent() {
        let pasteboard = NSPasteboard(name: .init("ExportTest-" + UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("Keep me", forType: .string)
        do {
            try MacClipboardService(pasteboard: pasteboard).writePNG(Data("bad".utf8))
            Issue.record("Invalid image should fail")
        } catch {
            #expect(pasteboard.string(forType: .string) == "Keep me")
        }
    }
}
