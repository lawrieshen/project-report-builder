import XCTest

@MainActor
final class ContentInputUITests: XCTestCase {
    func testReviewProtectsExistingContentAndCancel() {
        let app = openReport()
        app.buttons["addContent"].click()
        let source = app.textViews["sourceText"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["processContent"].isEnabled)
        source.click()
        source.typeText("Summary: Original summary")
        app.buttons["processContent"].click()
        let summary = app.checkBoxes["suggestion.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual((summary.value as? NSNumber)?.intValue, 1)
        app.buttons["applyContent"].click()
        XCTAssertTrue(app.buttons["saveReport"].waitForExistence(timeout: 5))
        app.buttons["saveReport"].click()
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"),
                                              object: app.buttons["saveReport"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
        app.buttons["addContent"].click()
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.click()
        source.typeText("Summary: Replacement summary\nHealth: Amber")
        app.buttons["processContent"].click()
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual((summary.value as? NSNumber)?.intValue, 0)
        XCTAssertTrue(app.staticTexts["Current: Original summary"].exists)
        app.buttons["cancelContent"].click()
        XCTAssertTrue(app.buttons["saveReport"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
    }

    func testNoSuggestionsAndSelectiveApply() {
        let app = openReport()
        app.buttons["addContent"].click()
        let source = app.textViews["sourceText"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.click()
        source.typeText("No labelled information")
        app.buttons["processContent"].click()
        XCTAssertTrue(app.staticTexts["No structured report information was detected."].waitForExistence(timeout: 5))
        source.click()
        source.typeKey("a", modifierFlags: .command)
        source.typeText("Project: Do not change\nSummary: New summary")
        app.buttons["processContent"].click()
        XCTAssertTrue(app.checkBoxes["suggestion.codeName"].waitForExistence(timeout: 5))
        XCTAssertEqual((app.checkBoxes["suggestion.codeName"].value as? NSNumber)?.intValue, 0)
        app.buttons["applyContent"].click()
        XCTAssertTrue(app.textFields["reportCodeName"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["reportCodeName"].value as? String, "Titan")
        XCTAssertTrue(app.buttons["saveReport"].isEnabled)
        app.buttons["discardReport"].click()
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
    }

    private func openReport() -> XCUIApplication {
        let app = XCUIApplication.isolated()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["newProjectButton"].waitForExistence(timeout: 10))
        app.buttons["newProjectButton"].click()
        let name = app.textFields["newProjectCodeName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("Titan")
        app.textFields["newProjectLineOfBusiness"].click()
        app.textFields["newProjectLineOfBusiness"].typeText("Camera")
        app.buttons["Create & Open"].click()
        XCTAssertTrue(app.buttons["addContent"].waitForExistence(timeout: 5))
        return app
    }
}
