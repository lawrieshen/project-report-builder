import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class AssetInputUITests: XCTestCase {
    func testImportPreviewReplaceRemoveAndDiscard() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try makeImage(at: root.appendingPathComponent("diagram.png"))
        let replacement = try makeImage(at: root.appendingPathComponent("replacement.png"))
        let app = openReport()
        let choose = app.buttons["chooseImages"]
        scrollTo(choose, in: app)
        choose.click()
        chooseFile(first, in: app)
        let alt = app.textFields["assetAltText.diagram.png"]
        XCTAssertTrue(alt.waitForExistence(timeout: 10))
        scrollTo(alt, in: app)
        alt.click()
        alt.typeText("System diagram")
        app.buttons["saveReport"].click()
        waitForSave(app)
        let preview = app.buttons["Preview diagram.png"]
        scrollTo(preview, in: app)
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
        app.buttons["discardReport"].click()
        XCTAssertTrue(alt.waitForExistence(timeout: 5))
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
        scrollTo(app.buttons["chooseImages"], in: app)
        XCTAssertTrue(alt.waitForExistence(timeout: 5))
        XCTAssertEqual(alt.value as? String, "System diagram")
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews["reportEditorScroll"]
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            scroll.scroll(byDeltaX: 0, deltaY: -250)
        }
        XCTAssertTrue(element.isHittable)
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

    private func makeImage(at url: URL) throws -> URL {
        let context = try XCTUnwrap(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8,
                                              bytesPerRow: 32, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
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
