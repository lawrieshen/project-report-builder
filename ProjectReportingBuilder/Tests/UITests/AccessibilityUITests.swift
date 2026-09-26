import XCTest

@MainActor
final class AccessibilityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAutomaticValidationUpdatesWithoutSaving() {
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
        XCTAssertTrue(app.staticTexts["reportValidationAllClear"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["checkAccessibility"].exists)
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)

        let title = app.textFields["reportCodeName"]
        title.click()
        title.typeKey("a", modifierFlags: .command)
        title.typeKey(.delete, modifierFlags: [])
        // Start away from Identity to verify that issue navigation actually scrolls.
        app.scrollViews["reportEditorScroll"].scroll(byDeltaX: 0, deltaY: -600)
        let navigate = app.buttons["reportValidationSection.identity"]
        XCTAssertTrue(navigate.waitForExistence(timeout: 5))
        navigate.click()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(title.isHittable)
        title.click()
        title.typeText("Updated Titan")
        XCTAssertTrue(app.staticTexts["reportValidationAllClear"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["reportValidationAllClear"].exists)
        let image = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        image.name = "Accessibility — unsaved fix passes"
        image.lifetime = .keepAlways
        add(image)
        XCTAssertTrue(app.buttons["saveReport"].isEnabled)
        app.buttons["discardReport"].click()
        XCTAssertEqual(title.value as? String, "Titan")
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
    }
}
