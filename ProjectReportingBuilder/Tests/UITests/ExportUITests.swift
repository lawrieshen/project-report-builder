import XCTest

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
        XCTAssertTrue(app.buttons["openExport"].waitForExistence(timeout: 5))
        return app
    }
}
