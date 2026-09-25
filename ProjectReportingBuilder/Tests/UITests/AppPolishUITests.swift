import XCTest

@MainActor
final class AppPolishUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testCommandsAndNativeSettings() {
        let app = XCUIApplication.isolated()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["newProjectButton"].waitForExistence(timeout: 10))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.textFields["newProjectCodeName"].waitForExistence(timeout: 5))
        app.textFields["newProjectCodeName"].click()
        app.textFields["newProjectCodeName"].typeText("Shortcut Titan")
        app.textFields["newProjectLineOfBusiness"].click()
        app.textFields["newProjectLineOfBusiness"].typeText("Camera")
        app.buttons["Create & Open"].click()
        let name = app.textFields["reportCodeName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("Saved with Shortcut")
        app.typeKey("s", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 5))
        app.typeKey("p", modifierFlags: .command)
        XCTAssertTrue(app.buttons["closeLivePreview"].waitForExistence(timeout: 5))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertFalse(app.textFields["newProjectCodeName"].exists)
        app.buttons["closeLivePreview"].click()
        app.typeKey("e", modifierFlags: .command)
        XCTAssertTrue(app.buttons["closeExport"].waitForExistence(timeout: 5))
        app.buttons["closeExport"].click()
        app.typeKey("a", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.buttons["closeAccessibility"].waitForExistence(timeout: 5))
        app.buttons["closeAccessibility"].click()
        app.typeKey(",", modifierFlags: .command)
        let autosave = app.checkBoxes["autosaveEnabled"]
        XCTAssertTrue(autosave.waitForExistence(timeout: 5))
        XCTAssertEqual(autosave.value as? Int, 0)
        autosave.click()
        app.typeKey("n", modifierFlags: .command)
        XCTAssertFalse(app.textFields["newProjectCodeName"].exists)
        app.typeKey("w", modifierFlags: .command)
        app.typeKey("o", modifierFlags: .command)
        XCTAssertTrue(app.buttons["Open Saved with Shortcut"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(autosave.waitForExistence(timeout: 5))
        XCTAssertEqual(autosave.value as? Int, 1)
    }
}
