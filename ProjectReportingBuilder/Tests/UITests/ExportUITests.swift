import XCTest
import AppKit

@MainActor
final class ExportUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testHTMLSaveCancellationAndUnsavedContent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = openReport()
        let title = app.textFields["reportCodeName"]
        title.click()
        title.typeKey("a", modifierFlags: .command)
        title.typeText("Draft & Export")
        app.buttons["openExport"].click()
        XCTAssertTrue(app.buttons["closeExport"].waitForExistence(timeout: 5))
        app.popUpButtons["exportFormat"].click()
        app.menuItems["HTML"].click()
        XCTAssertFalse(app.popUpButtons["exportScale"].exists)
        XCTAssertFalse(app.popUpButtons["exportBackground"].exists)
        app.buttons["saveExport"].click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
        app.sheets.buttons["Cancel"].click()
        XCTAssertTrue(app.buttons["saveExport"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["exportSuccess"].exists)
        app.buttons["saveExport"].click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(directory.path)
        app.typeKey(.return, modifierFlags: [])
        let save = app.sheets.buttons["Save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.click()
        let url = directory.appendingPathComponent("Draft-Export.html")
        let written = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: url.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [written], timeout: 10), .completed)
        let html = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(html.contains("<h1>Draft &amp; Export</h1>"))
        XCTAssertTrue(app.staticTexts["exportSuccess"].waitForExistence(timeout: 5))
        let image = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        image.name = "Export — saved unsaved HTML draft"
        image.lifetime = .keepAlways
        add(image)
        app.buttons["closeExport"].click()
        XCTAssertTrue(app.buttons["saveReport"].isEnabled)
        app.buttons["discardReport"].click()
        XCTAssertEqual(title.value as? String, "Titan")
    }

    func testHighResolutionTransparentPNGAndNativeShareCancellation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = openReport()
        app.buttons["openExport"].click()
        XCTAssertTrue(app.buttons["closeExport"].waitForExistence(timeout: 5))
        app.popUpButtons["exportScale"].click()
        app.menuItems["High Resolution"].click()
        app.popUpButtons["exportBackground"].click()
        app.menuItems["Transparent"].click()
        app.buttons["saveExport"].click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText(directory.path)
        app.typeKey(.return, modifierFlags: [])
        let save = app.sheets.buttons["Save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.click()
        let url = directory.appendingPathComponent("Titan.png")
        let written = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: url.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [written], timeout: 10), .completed)
        let image = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
        XCTAssertEqual(image.pixelsWide, 1440)
        XCTAssertEqual(image.colorAt(x: 1, y: 1)?.alphaComponent, 0)
        app.buttons["shareExport"].click()
        let picker = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.menus.firstMatch.exists || app.popovers.firstMatch.exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [picker], timeout: 8), .completed)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.buttons["closeExport"].waitForExistence(timeout: 5))
        app.buttons["closeExport"].click()
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
    }

    func testAccessibilityReviewAndExportAnyway() {
        let app = openReport()
        let title = app.textFields["reportCodeName"]
        title.click()
        title.typeKey("a", modifierFlags: .command)
        title.typeKey(.delete, modifierFlags: [])
        app.buttons["openExport"].click()
        app.buttons["saveExport"].click()
        XCTAssertTrue(app.buttons["exportAnyway"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.sheets.firstMatch.exists)
        app.buttons["reviewExportIssues"].click()
        let identity = app.buttons["accessibilitySection.identity"]
        XCTAssertTrue(identity.waitForExistence(timeout: 5))
        identity.click()
        XCTAssertTrue(title.isHittable)
        app.buttons["openExport"].click()
        app.buttons["saveExport"].click()
        XCTAssertTrue(app.buttons["exportAnyway"].waitForExistence(timeout: 5))
        app.buttons["exportAnyway"].click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
        app.sheets.buttons["Cancel"].click()
        app.buttons["closeExport"].click()
        XCTAssertEqual(title.value as? String, "")
        XCTAssertTrue(app.staticTexts["Unsaved Changes"].exists)
        title.click()
        title.typeText("Fixed title")
        app.buttons["openExport"].click()
        app.buttons["saveExport"].click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["exportAnyway"].exists)
        app.sheets.buttons["Cancel"].click()
        app.buttons["closeExport"].click()
        XCTAssertTrue(app.buttons["saveReport"].isEnabled)
    }

    private func openReport() -> XCUIApplication {
        let app = XCUIApplication.isolated()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.activate()
        XCTAssertTrue(app.buttons["newProjectButton"].waitForExistence(timeout: 10))
        app.buttons["newProjectButton"].click()
        let name = app.textFields["newProjectCodeName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("Titan")
        app.popUpButtons["newProjectLineOfBusiness"].click()
        app.menuItems["iPhone"].click()
        app.buttons["Create & Open"].click()
        XCTAssertTrue(app.buttons["openExport"].waitForExistence(timeout: 5))
        return app
    }
}
