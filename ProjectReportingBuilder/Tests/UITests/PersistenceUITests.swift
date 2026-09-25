import XCTest

@MainActor
final class PersistenceUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSavedProjectSurvivesRelaunch() {
        let app = XCUIApplication.isolated()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["newProjectButton"].waitForExistence(timeout: 10))
        app.buttons["newProjectButton"].click()
        app.textFields["newProjectCodeName"].click()
        app.textFields["newProjectCodeName"].typeText("Persistent Titan")
        app.textFields["newProjectLineOfBusiness"].click()
        app.textFields["newProjectLineOfBusiness"].typeText("Camera")
        app.buttons["Create & Open"].click()
        XCTAssertTrue(app.textFields["reportCodeName"].waitForExistence(timeout: 5))
        let title = app.textFields["reportCodeName"]
        title.click()
        title.typeKey("a", modifierFlags: .command)
        title.typeText("Saved Titan")
        app.buttons["saveReport"].click()
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !app.buttons["saveReport"].isEnabled
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
