import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class AssetInputUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testImportPreviewReplaceRemoveAndDiscard() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try makeImage(at: root.appendingPathComponent("diagram.png"), label: "A", color: .blue)
        let replacement = try makeImage(at: root.appendingPathComponent("replacement.png"), label: "B", color: .orange)
        let app = openReport()
        let choose = app.buttons["chooseImages"]
        scrollTo(choose, in: app)
        choose.click()
        chooseFile(first, in: app)
        let alt = app.textFields["assetAltText.diagram.png"]
        scrollTo(alt, in: app)
        XCTAssertTrue(alt.waitForExistence(timeout: 10))
        alt.click()
        alt.typeText("System diagram")
        app.buttons["saveReport"].click()
        waitForSave(app)
        let preview = app.buttons["Preview diagram.png"]
        scrollTo(preview, in: app)
        assertImageColor(.blue, in: preview, named: "Original — blue A")
        preview.click()
        XCTAssertTrue(app.buttons["closeImagePreview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["System diagram"].exists)
        app.buttons["closeImagePreview"].click()
        let menu = app.descendants(matching: .any).matching(identifier: "assetActions.diagram.png").firstMatch
        scrollTo(menu, in: app)
        menu.click()
        app.menuItems["Replace Image"].click()
        chooseFile(replacement, in: app)
        let replacedAlt = app.textFields["assetAltText.replacement.png"]
        XCTAssertTrue(replacedAlt.waitForExistence(timeout: 10))
        XCTAssertEqual(replacedAlt.value as? String, "System diagram")
        let replacedPreview = app.buttons["Preview replacement.png"]
        scrollTo(replacedPreview, in: app)
        assertImageColor(.orange, in: replacedPreview, named: "Replacement — orange B")
        app.buttons["discardReport"].click()
        XCTAssertTrue(alt.waitForExistence(timeout: 5))
        scrollTo(preview, in: app)
        assertImageColor(.blue, in: preview, named: "Discard replacement — restored blue A")
        scrollTo(menu, in: app)
        menu.click()
        app.menuItems["Remove"].click()
        XCTAssertFalse(alt.exists)
        XCTAssertTrue(app.buttons["saveReport"].isEnabled)
        app.buttons["discardReport"].click()
        XCTAssertTrue(alt.waitForExistence(timeout: 5))
        app.buttons["workspaceBack"].click()
        XCTAssertTrue(app.buttons["Open Titan"].waitForExistence(timeout: 5))
        app.buttons["Open Titan"].click()
        scrollTo(alt, in: app)
        XCTAssertTrue(alt.waitForExistence(timeout: 5))
        XCTAssertEqual(alt.value as? String, "System diagram")
        scrollTo(preview, in: app)
        assertImageColor(.blue, in: preview, named: "Reopened — saved blue A")
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews["reportEditorScroll"]
        for _ in 0..<12 {
            let viewport = scroll.frame.insetBy(dx: 0, dy: 4)
            if element.exists {
                let frame = element.frame
                // Hittable can be true even when most of the image is outside the viewport.
                if element.isHittable && frame.minY >= viewport.minY && frame.maxY <= viewport.maxY {
                    return
                }
                scroll.scroll(byDeltaX: 0, deltaY: frame.minY < viewport.minY ? 150 : -150)
            } else {
                scroll.scroll(byDeltaX: 0, deltaY: -150)
            }
        }
        XCTFail("Could not fully reveal " + element.description)
    }

    private func chooseFile(_ url: URL, in app: XCUIApplication) {
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(url.path)
        app.typeKey(.return, modifierFlags: [])
        let open = app.sheets.buttons["Open"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.click()
    }

    private func waitForSave(_ app: XCUIApplication) {
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"),
                                              object: app.buttons["saveReport"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
    }

    private enum FixtureColor {
        case blue, orange

        var background: NSColor {
            switch self {
            case .blue: return NSColor(srgbRed: 0.1, green: 0.3, blue: 0.9, alpha: 1)
            case .orange: return NSColor(srgbRed: 0.95, green: 0.5, blue: 0.05, alpha: 1)
            }
        }

        func matches(_ color: NSColor) -> Bool {
            switch self {
            case .blue:
                return color.blueComponent > color.redComponent + 0.25
                    && color.blueComponent > color.greenComponent + 0.15
            case .orange:
                return color.redComponent > color.blueComponent + 0.4
                    && color.greenComponent > color.blueComponent + 0.2
            }
        }
    }

    private func makeImage(at url: URL, label: String, color: FixtureColor) throws -> URL {
        let size = CGSize(width: 256, height: 160)
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(data: nil, width: 256, height: 160, bitsPerComponent: 8,
                                              bytesPerRow: 256 * 4,
                                              space: colorSpace,
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }
        context.setFillColor(color.background.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 96),
            .foregroundColor: NSColor.white
        ]
        let text = label as NSString
        let textSize = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: (size.width - textSize.width) / 2,
                              y: (size.height - textSize.height) / 2), withAttributes: attributes)
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    /// Check rendered pixels rather than filenames; tolerate scaling and color profiles.
    private func assertImageColor(_ expected: FixtureColor, in element: XCUIElement, named name: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.hasDominantColor(expected, screenshot: element.screenshot())
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 8), .completed,
                       "The displayed thumbnail should match " + name, file: file, line: line)
        let attachment = XCTAttachment(screenshot: element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func hasDominantColor(_ expected: FixtureColor, screenshot: XCUIScreenshot) -> Bool {
        guard let bitmap = NSBitmapImageRep(data: screenshot.pngRepresentation) else { return false }
        var matching = 0
        var sampled = 0
        // Sample the whole thumbnail: its colored area must be substantial, not one incidental pixel.
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
                sampled += 1
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                   expected.matches(color) { matching += 1 }
            }
        }
        return sampled > 0 && Double(matching) / Double(sampled) > 0.35
    }

    private func openReport() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.activate()
        XCTAssertTrue(app.buttons["newProjectButton"].waitForExistence(timeout: 10))
        app.buttons["newProjectButton"].click()
        let name = app.textFields["newProjectCodeName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("Titan")
        app.textFields["newProjectLineOfBusiness"].click()
        app.textFields["newProjectLineOfBusiness"].typeText("Camera")
        app.buttons["Create & Open"].click()
        XCTAssertTrue(app.buttons["addContent"].waitForExistence(timeout: 5))
        return app
    }
}
