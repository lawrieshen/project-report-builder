import AppKit
import Testing
@testable import Project_Report_Builder

@MainActor
struct ReportExportRendererTests {
    static func draft() -> ReportEditorDraft {
        ReportEditorDraft(project: ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                                 status: .active, createdAt: .now, updatedAt: .now))
    }

    @Test func pngHasCorrectDimensionsFormatAndBackground() async throws {
        let renderer = ReportExportRenderer { _ in throw ExportError.renderingFailed }
        let model = ReportPreviewModel(draft: Self.draft())
        let normal = try await renderer.render(model: model, options: ExportOptions())
        let high = try await renderer.render(model: model, options: ExportOptions(imageScale: .highResolution))
        let first = try #require(NSBitmapImageRep(data: normal.data))
        let second = try #require(NSBitmapImageRep(data: high.data))
        #expect(normal.fileName == "Titan.png" && normal.contentType == .png)
        #expect(first.pixelsWide == 720 && second.pixelsWide == 1440)
        #expect(abs(second.pixelsHigh - first.pixelsHigh * 2) <= 1)
        #expect(first.colorAt(x: 0, y: 0)?.alphaComponent == 1)
        let clear = try await renderer.render(model: model, options: ExportOptions(background: .transparent))
        let transparent = try #require(NSBitmapImageRep(data: clear.data))
        #expect(transparent.colorAt(x: 1, y: 1)?.alphaComponent == 0)
        let dark = try await renderer.render(model: model, options: ExportOptions(background: .system, appearance: .dark))
        let darkImage = try #require(NSBitmapImageRep(data: dark.data))
        #expect(try #require(darkImage.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB)).redComponent < 0.2)
    }

    @Test func longReportsIncludeBottomImagesAndPreserveDraft() async throws {
        var draft = Self.draft()
        draft.summaryMessage = String(repeating: "Unsaved report details.\n", count: 70)
        draft.assets = [ImageAsset(id: UUID(), fileName: "red.png", localReference: "red", altText: "Red diagram")]
        let before = draft
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8,
                                             bytesPerRow: 32, space: space,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(try #require(CGColor(colorSpace: space, components: [1, 0, 0, 1])))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let sourceImage = try #require(context.makeImage())
        let png = try #require(NSBitmapImageRep(cgImage: sourceImage).representation(using: .png, properties: [:]))
        let renderer = ReportExportRenderer { _ in png }
        let prepared = try await renderer.preparedImages(draft.assets)
        let preparedImage = try #require(prepared["red"]?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let preparedBitmap = NSBitmapImageRep(cgImage: preparedImage)
        #expect(try #require(preparedBitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB)).redComponent > 0.8)
        #expect(preparedBitmap.colorAt(x: 0, y: 0)?.alphaComponent == 1)
        let result = try await renderer.render(model: ReportPreviewModel(draft: draft), options: ExportOptions())
        let image = try #require(NSBitmapImageRep(data: result.data))
        #expect(image.pixelsHigh > 1000)
        let bottomImage = try #require(image.colorAt(x: 360, y: image.pixelsHigh - 110)?.usingColorSpace(.sRGB))
        #expect(bottomImage.redComponent > bottomImage.greenComponent + 0.4)
        #expect(bottomImage.redComponent > bottomImage.blueComponent + 0.4)
        #expect(draft == before)
    }

    @Test func missingImagesFailRatherThanExportingPlaceholders() async {
        var draft = Self.draft()
        draft.assets = [ImageAsset(id: UUID(), fileName: "broken.png", localReference: "broken")]
        let renderer = ReportExportRenderer { _ in Data("bad".utf8) }
        do {
            _ = try await renderer.render(model: ReportPreviewModel(draft: draft), options: ExportOptions())
            Issue.record("Missing image should fail")
        } catch {
            #expect(error.localizedDescription.contains("broken.png"))
        }
    }

    @Test func rasterLimitsRejectUnboundedAllocations() {
        #expect(!ReportExportRenderer.isSafeRasterSize(CGSize(width: 720, height: 100_000), scale: 2))
        #expect(!ReportExportRenderer.isSafeRasterSize(CGSize(width: Double.infinity, height: 1), scale: 1))
        #expect(ReportExportRenderer.isSafeRasterSize(CGSize(width: 720, height: 1000), scale: 2))
    }
}
