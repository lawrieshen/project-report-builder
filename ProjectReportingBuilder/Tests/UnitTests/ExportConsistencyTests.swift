import SwiftUI
import Testing
@testable import Project_Report_Builder

@MainActor
struct ExportConsistencyTests {
    @Test func pngMatchesCanonicalPreviewAndKeepsImageOrder() async throws {
        var draft = ReportExportRendererTests.draft()
        draft.ragStatus = .amber
        draft.summaryMessage = "Current unsaved summary"
        draft.leadEPMName = "Jane"
        draft.projectDRIName = "Alex"
        let now = Date(timeIntervalSince1970: 1_790_294_400)
        draft.milestoneDeadline = Calendar.current.date(byAdding: .day, value: 2, to: now)
        draft.assets = [ImageAsset(id: UUID(), fileName: "red.png", localReference: "red", altText: "First red"),
                        ImageAsset(id: UUID(), fileName: "blue.png", localReference: "blue", altText: "Second blue")]
        let red = try fixture(red: 1, blue: 0), blue = try fixture(red: 0, blue: 1)
        let model = ReportPreviewModel(draft: draft)
        let exporter = ReportExportRenderer { $0.localReference == "red" ? red : blue }
        let options = ExportOptions(date: now)
        let output = try await exporter.render(model: model, options: options)
        let actual = try #require(NSBitmapImageRep(data: output.data))
        let images = try await exporter.preparedImages(draft.assets)
        let reference = ImageRenderer(content: ReportCardView(model: model,
            images: images.mapValues { .loaded($0) }, now: now)
            .frame(width: ReportCardStyle.standardWidth)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.colorScheme, .light)
            .background(Color.white))
        reference.scale = 1
        let expected = NSBitmapImageRep(cgImage: try #require(reference.cgImage))
        #expect(actual.pixelsWide == expected.pixelsWide && actual.pixelsHigh == expected.pixelsHigh)
        var mismatches = 0
        var samples = 0
        var leftRed = 0
        var rightBlue = 0
        // Compare normalized pixels with tolerance for rasterization/color-profile differences.
        for y in stride(from: 0, to: min(actual.pixelsHigh, expected.pixelsHigh), by: 4) {
            for x in stride(from: 0, to: min(actual.pixelsWide, expected.pixelsWide), by: 4) {
                let a = try #require(actual.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                let b = try #require(expected.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                samples += 1
                if abs(a.redComponent - b.redComponent) > 0.1 || abs(a.greenComponent - b.greenComponent) > 0.1
                    || abs(a.blueComponent - b.blueComponent) > 0.1 { mismatches += 1 }
                if x < 360 && a.redComponent > a.blueComponent + 0.4 { leftRed += 1 }
                if x > 360 && a.blueComponent > a.redComponent + 0.4 { rightBlue += 1 }
            }
        }
        #expect(Double(mismatches) / Double(samples) < 0.02)
        #expect(leftRed > 100 && rightBlue > 100)
        var htmlOptions = options
        htmlOptions.format = .html
        let htmlResult = try await exporter.render(model: model, options: htmlOptions)
        let html = try #require(String(data: htmlResult.data, encoding: .utf8))
        #expect(html.contains("2 days remaining"))
        let first = try #require(html.range(of: "alt=\"First red\""))
        let second = try #require(html.range(of: "alt=\"Second blue\""))
        #expect(first.lowerBound < second.lowerBound)
        #expect(html.contains("Current unsaved summary"))
    }

    private func fixture(red: CGFloat, blue: CGFloat) throws -> Data {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 24, height: 16, bitsPerComponent: 8,
            bytesPerRow: 96, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(try #require(CGColor(colorSpace: space, components: [red, 0, blue, 1])))
        context.fill(CGRect(x: 0, y: 0, width: 24, height: 16))
        let pixels = try #require(context.makeImage())
        return try #require(NSBitmapImageRep(cgImage: pixels).representation(using: .png, properties: [:]))
    }
}
