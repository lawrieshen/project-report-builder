import XCTest

@MainActor
final class LivePreviewUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testUnsavedPreviewControlsAndDiscard() {
        let app = openReport()
        app.buttons["addMetric"].click()
        let metricName = app.textFields["metricName"]
        XCTAssertTrue(metricName.waitForExistence(timeout: 5))
        metricName.click()
        metricName.typeText("Latency")
        app.textFields["metricCurrentValue"].click()
        app.textFields["metricCurrentValue"].typeText("120")
        app.checkBoxes["metricHasTarget"].click()
        app.textFields["metricTargetValue"].click()
        app.textFields["metricTargetValue"].typeText("100")
        app.buttons["saveMetric"].click()
        app.buttons["addContent"].click()
        let source = app.textViews["sourceText"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.click()
        source.typeText("Health: Amber\nMilestone: DVT\nDeadline: 2026-09-30\nSummary: Saved summary\nLead EPM: Jane\nProject DRI: Alex")
        app.buttons["processContent"].click()
        XCTAssertTrue(app.buttons["applyContent"].waitForExistence(timeout: 5))
        app.buttons["applyContent"].click()
        app.buttons["saveReport"].click()
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"),
                                              object: app.buttons["saveReport"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)

        app.buttons["addContent"].click()
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.click()
        source.typeText("Summary: Unsaved summary")
        app.buttons["processContent"].click()
        let selection = app.checkBoxes["suggestion.summary"]
        XCTAssertTrue(selection.waitForExistence(timeout: 5))
        selection.click()
        app.buttons["applyContent"].click()
        app.buttons["openLivePreview"].click()
        XCTAssertTrue(app.buttons["closeLivePreview"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["previewSummary"].value as? String, "Unsaved summary")
        XCTAssertFalse(app.staticTexts["On Track"].exists)
        XCTAssertTrue(app.staticTexts["At Risk"].exists)
        XCTAssertTrue(app.staticTexts["DVT"].exists)
        XCTAssertTrue(app.staticTexts["Target Missed"].exists)
        capture(app, name: "Live Preview — accountability diagnostics")
        XCTAssertTrue(app.staticTexts["Jane"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts["Alex"].exists)
        app.buttons["Actual Size"].click()
        XCTAssertEqual(app.staticTexts["previewZoom"].value as? String, "100%")
        app.buttons["Zoom In"].click()
        XCTAssertEqual(app.staticTexts["previewZoom"].value as? String, "110%")
        app.buttons["Zoom Out"].click()
        XCTAssertEqual(app.staticTexts["previewZoom"].value as? String, "100%")
        app.buttons["Fit"].click()
        let appearance = app.popUpButtons["previewAppearance"]
        appearance.click()
        app.menuItems["Dark"].click()
        capture(app, name: "Live Preview — Dark")
        appearance.click()
        app.menuItems["Light"].click()
        capture(app, name: "Live Preview — Light")
        app.buttons["closeLivePreview"].click()
        XCTAssertTrue(app.buttons["saveReport"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["saveReport"].isEnabled)
        app.buttons["discardReport"].click()
        app.buttons["openLivePreview"].click()
        XCTAssertTrue(app.buttons["closeLivePreview"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["previewSummary"].value as? String, "Saved summary")
        app.buttons["closeLivePreview"].click()
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
    }

    func testIncompleteDraftStillPreviewsWithoutSaving() {
        let app = openReport()
        let name = app.textFields["reportCodeName"]
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeKey(.delete, modifierFlags: [])
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
        app.buttons["openLivePreview"].click()
        XCTAssertTrue(app.buttons["closeLivePreview"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["previewCodeName"].label, "Untitled Project")
        XCTAssertFalse(app.staticTexts["Engineering Metrics"].exists)
        XCTAssertFalse(app.staticTexts["Latest Update"].exists)
        XCTAssertFalse(app.staticTexts["Supporting Assets"].exists)
        XCTAssertFalse(app.staticTexts["Lead EPM"].exists)
        capture(app, name: "Live Preview — Incomplete report")
        app.buttons["closeLivePreview"].click()
        XCTAssertTrue(app.textFields["reportCodeName"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["reportCodeName"].value as? String, "")
        XCTAssertTrue(app.staticTexts["Unsaved Changes"].exists)
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openReport() -> XCUIApplication {
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
        app.textFields["newProjectLineOfBusiness"].click()
        app.textFields["newProjectLineOfBusiness"].typeText("Camera")
        app.buttons["Create & Open"].click()
        XCTAssertTrue(app.buttons["openLivePreview"].waitForExistence(timeout: 5))
        return app
    }
}
