import XCTest

final class CloudEntryUITests: XCTestCase {
    @MainActor
    func testCloudWorkspaceRequiresSignIn() {
        let app = XCUIApplication.isolated()
        app.launchEnvironment["PROJECT_REPORT_TEST_CLOUD_GATE"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["cloudSignIn"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["cloudEmail"].exists)
        XCTAssertTrue(app.secureTextFields["cloudPassword"].exists)
        XCTAssertFalse(app.buttons["cloudSignIn"].isEnabled)
        app.textFields["cloudEmail"].click()
        app.textFields["cloudEmail"].typeText("test@example.com")
        app.secureTextFields["cloudPassword"].click()
        app.secureTextFields["cloudPassword"].typeText("test-password")
        XCTAssertTrue(app.buttons["cloudSignIn"].isEnabled)
        XCTAssertFalse(app.buttons["newProjectButton"].exists)
        app.terminate()
    }
}
