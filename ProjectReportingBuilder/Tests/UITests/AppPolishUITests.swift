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
    func testAutosaveAndWorkspaceRestore() {
        let app = XCUIApplication.isolated()
        app.launchEnvironment["PROJECT_REPORT_MANUAL_SAVE"] = "0"
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        createProject(in: app, name: "Autosave Titan")
        let name = app.textFields["reportCodeName"]
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("Automatically Saved")
        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 8))
        app.terminate()
        app.launch()
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertEqual(name.value as? String, "Automatically Saved")
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
        XCTAssertFalse(app.buttons["restoreRecovery"].exists)
    }

    func testDeletePreferenceKeepsRecoveryCleanupConfirmation() {
        let app = XCUIApplication.isolated()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        createProject(in: app, name: "Delete Preference")
        app.typeKey(",", modifierFlags: .command)
        let confirmation = app.checkBoxes["Confirm before deleting projects"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.click()
        app.staticTexts["Storage"].click()
        let clear = app.buttons["clearRecoveryDrafts"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.click()
        XCTAssertTrue(app.buttons["confirmClearRecovery"].waitForExistence(timeout: 5))
        app.sheets.buttons["Cancel"].click()
        app.typeKey("w", modifierFlags: .command)
        app.typeKey("o", modifierFlags: .command)
        let project = app.buttons["Open Delete Preference"]
        XCTAssertTrue(project.waitForExistence(timeout: 5))
        project.rightClick()
        app.windows["main"].menuItems["Delete"].click()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !project.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed)
        XCTAssertFalse(app.sheets.buttons["Delete"].exists)
    }

    func testAppearancePreferenceSurvivesRelaunch() {
        let app = XCUIApplication.isolated()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["newProjectButton"].waitForExistence(timeout: 10))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 5))
        app.staticTexts["Appearance"].click()
        app.radioButtons["Dark"].click()
        XCTAssertEqual(app.radioButtons["Dark"].value as? Int, 1)
        app.terminate()
        app.launch()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 5))
        app.staticTexts["Appearance"].click()
        XCTAssertEqual(app.radioButtons["Dark"].value as? Int, 1)
        app.radioButtons["System"].click()
        XCTAssertEqual(app.radioButtons["System"].value as? Int, 1)
    }

    private func createProject(in app: XCUIApplication, name: String) {
        XCTAssertTrue(app.buttons["newProjectButton"].waitForExistence(timeout: 10))
        app.buttons["newProjectButton"].click()
        app.textFields["newProjectCodeName"].click()
        app.textFields["newProjectCodeName"].typeText(name)
        app.textFields["newProjectLineOfBusiness"].click()
        app.textFields["newProjectLineOfBusiness"].typeText("Camera")
        app.buttons["Create & Open"].click()
        XCTAssertTrue(app.textFields["reportCodeName"].waitForExistence(timeout: 5))
    }

}
