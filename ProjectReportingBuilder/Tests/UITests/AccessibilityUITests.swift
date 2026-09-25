import XCTest

@MainActor
final class AccessibilityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testCheckNavigateFixAndRecheckWithoutSaving() {
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
        let check = app.buttons["checkAccessibility"]
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        check.click()
        XCTAssertTrue(app.staticTexts["accessibilityAllClear"].waitForExistence(timeout: 5))
        app.buttons["closeAccessibility"].click()
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)

        let title = app.textFields["reportCodeName"]
        title.click()
        title.typeKey("a", modifierFlags: .command)
        title.typeKey(.delete, modifierFlags: [])
        // Start away from Identity to verify that issue navigation actually scrolls.
        app.scrollViews["reportEditorScroll"].scroll(byDeltaX: 0, deltaY: -600)
        check.click()
        let navigate = app.buttons["accessibilitySection.identity"]
        XCTAssertTrue(navigate.waitForExistence(timeout: 5))
        navigate.click()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(title.isHittable)
        title.click()
        title.typeText("Updated Titan")
        check.click()
        XCTAssertTrue(app.staticTexts["accessibilityAllClear"].waitForExistence(timeout: 5))
        app.buttons["recheckAccessibility"].click()
        XCTAssertTrue(app.staticTexts["accessibilityAllClear"].exists)
        let image = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        image.name = "Accessibility — unsaved fix passes"
        image.lifetime = .keepAlways
        add(image)
        app.buttons["closeAccessibility"].click()
        XCTAssertTrue(app.buttons["saveReport"].isEnabled)
        app.buttons["discardReport"].click()
        XCTAssertEqual(title.value as? String, "Titan")
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
    }
}
