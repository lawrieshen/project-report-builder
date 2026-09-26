import XCTest

@MainActor
final class PersistenceUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testRecoverUnsavedDraftAfterTermination() {
        let app = XCUIApplication.isolated()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["newProjectButton"].waitForExistence(timeout: 10))
        app.buttons["newProjectButton"].click()
        app.textFields["newProjectCodeName"].click()
        app.textFields["newProjectCodeName"].typeText("Recovery Titan")
        app.popUpButtons["newProjectLineOfBusiness"].click()
        app.menuItems["iPhone"].click()
        app.buttons["Create & Open"].click()
        let title = app.textFields["reportCodeName"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.click()
        title.typeKey("a", modifierFlags: .command)
        title.typeText("Unsaved Titan")
        XCTAssertTrue(app.staticTexts["Draft backed up locally"].waitForExistence(timeout: 8))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Open Recovery Titan"].waitForExistence(timeout: 10))
        app.buttons["Open Recovery Titan"].click()
        XCTAssertTrue(app.buttons["restoreRecovery"].waitForExistence(timeout: 5))
        app.buttons["restoreRecovery"].click()
        XCTAssertEqual(title.value as? String, "Unsaved Titan")
        XCTAssertTrue(app.buttons["saveReport"].isEnabled)
        app.buttons["discardReport"].click()
        XCTAssertEqual(title.value as? String, "Recovery Titan")
        app.buttons["workspaceBack"].click()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Open Recovery Titan"].waitForExistence(timeout: 10))
        app.buttons["Open Recovery Titan"].click()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["restoreRecovery"].exists)
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
    }

    func testDuplicateAndDeleteSurviveRelaunch() {
        let app = XCUIApplication.isolated()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["newProjectButton"].waitForExistence(timeout: 10))
        app.buttons["newProjectButton"].click()
        app.textFields["newProjectCodeName"].click()
        app.textFields["newProjectCodeName"].typeText("Original")
        app.popUpButtons["newProjectLineOfBusiness"].click()
        app.menuItems["iPhone"].click()
        app.buttons["Create & Open"].click()
        XCTAssertTrue(app.buttons["workspaceBack"].waitForExistence(timeout: 5))
        app.buttons["workspaceBack"].click()
        XCTAssertTrue(app.buttons["Open Original"].waitForExistence(timeout: 5))
        app.buttons["Open Original"].rightClick()
        app.menuItems["Duplicate"].click()
        XCTAssertTrue(app.buttons["confirmDuplicate"].waitForExistence(timeout: 5))
        app.buttons["confirmDuplicate"].click()
        XCTAssertTrue(app.buttons["Open Original Copy"].waitForExistence(timeout: 5))
        app.buttons["Open Original Copy"].rightClick()
        app.windows.firstMatch.menuItems["Delete"].click()
        let confirmDelete = app.sheets.buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.click()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !app.buttons["Open Original Copy"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Open Original"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Open Original Copy"].exists)
    }

    func testSavedProjectSurvivesRelaunch() {
        let app = XCUIApplication.isolated()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["newProjectButton"].waitForExistence(timeout: 10))
        app.buttons["newProjectButton"].click()
        app.textFields["newProjectCodeName"].click()
        app.textFields["newProjectCodeName"].typeText("Persistent Titan")
        app.popUpButtons["newProjectLineOfBusiness"].click()
        app.menuItems["iPhone"].click()
        app.buttons["Create & Open"].click()
        XCTAssertTrue(app.textFields["reportCodeName"].waitForExistence(timeout: 5))
        let title = app.textFields["reportCodeName"]
        title.click()
        title.typeKey("a", modifierFlags: .command)
        title.typeText("Saved Titan")
        app.buttons["saveReport"].click()
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.buttons["saveReport"].exists && !app.staticTexts["Unsaved Changes"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Open Saved Titan"].waitForExistence(timeout: 10))
        app.buttons["Open Saved Titan"].click()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Saved Titan")
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
    }
}
