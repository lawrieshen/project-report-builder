import AppKit
import Testing
@testable import Project_Report_Builder

@MainActor
struct ReportHTMLRendererTests {
    @Test func htmlEscapesContentAndKeepsSemanticOrder() async throws {
        var draft = ReportExportRendererTests.draft()
        draft.codeName = "<script>alert('x')</script>"
        draft.summaryMessage = "Unsaved <update> & details"
        draft.summaryType = .ask
        draft.ragStatus = .red
        draft.milestonePhase = "DVT"
        draft.leadEPMName = "Jane"
        draft.projectDRIName = "Alex"
        var metric = EngineeringMetricDraft()
        metric.name = "Latency"
        metric.currentValueText = "120"
        metric.unit = "ms"
        draft.metrics = [metric]
        let result = try await ReportExportRenderer { _ in throw ExportError.renderingFailed }
            .render(model: ReportPreviewModel(draft: draft), options: ExportOptions(format: .html))
        let html = try #require(String(data: result.data, encoding: .utf8))
        #expect(result.contentType == .html && result.fileName.hasSuffix(".html"))
        #expect(html.contains("&lt;script&gt;") && !html.contains("<script>"))
        #expect(html.contains("Unsaved &lt;update&gt; &amp; details"))
        #expect(html.contains("120 ms") && html.contains("At Risk") == false)
        #expect(html.contains(draft.ragStatus!.displayName))
        let sections = ["<header>", "id=\"health\"", "id=\"metrics\"", "id=\"summary\"", "id=\"accountability\""]
        var end = html.startIndex
        for section in sections {
            let range = try #require(html.range(of: section, range: end..<html.endIndex))
            end = range.upperBound
        }
        #expect(html.contains("<dt>Lead EPM</dt><dd>Jane</dd>"))
    }

    @Test func imagesAreEmbeddedAndAltTextCannotInjectMarkup() throws {
        var draft = ReportExportRendererTests.draft()
        draft.assets = [ImageAsset(id: UUID(), fileName: "A.png", localReference: "a", altText: "\" onload=\"bad <&")]
        let image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            NSColor.blue.setFill(); rect.fill(); return true
        }
        let data = try ReportHTMLRenderer.render(model: ReportPreviewModel(draft: draft), images: ["a": image], options: ExportOptions(format: .html))
        let html = try #require(String(data: data, encoding: .utf8))
        #expect(html.contains("src=\"data:image/png;base64,"))
        #expect(html.contains("alt=\"&quot; onload=&quot;bad &lt;&amp;\""))
        #expect(!html.contains("file://"))
    }

    @Test func optionalSectionsStayAbsentAndInvalidMetricsStayVisible() throws {
        var draft = ReportExportRendererTests.draft()
        draft.metrics = [EngineeringMetricDraft()]
        let data = try ReportHTMLRenderer.render(model: ReportPreviewModel(draft: draft), images: [:], options: ExportOptions(format: .html))
        let html = try #require(String(data: data, encoding: .utf8))
        #expect(html.contains("Incomplete metric") && html.contains("Untitled metric"))
        #expect(!html.contains("id=\"health\"") && !html.contains("id=\"supportingContent\""))
    }
}
