import XCTest

final class CloudEntryUITests: XCTestCase {
    @MainActor
    func testCloudWorkspaceRequiresSignIn() {
        let app = XCUIApplication.isolated()
        app.launchEnvironment["PROJECT_REPORT_TEST_CLOUD_GATE"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["cloudSignIn"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["newProjectButton"].exists)
        app.terminate()
    }
}
