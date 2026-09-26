import XCTest

@MainActor
final class MetricsUITests: XCTestCase {
    func testAddMetricAndCancelEditing() {
        let app = openReport()
        app.buttons["addMetric"].click()
        let name = app.textFields["metricName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("Latency")
        let current = app.textFields["metricCurrentValue"]
        current.click()
        current.typeText("120")
        app.checkBoxes["metricHasTarget"].click()
        app.textFields["metricTargetValue"].click()
        app.textFields["metricTargetValue"].typeText("100")
        app.buttons["saveMetric"].click()
        let row = app.buttons["Edit metric Latency"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["saveReport"].isEnabled)
        row.click()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("Do not keep")
        app.buttons["cancelMetric"].click()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Edit metric Do not keep"].exists)
    }

    func testSaveReopenReorderAndDeleteDiscard() {
        let app = openReport()
        addMetric(in: app, name: "Latency", current: "120")
        addMetric(in: app, name: "Build Success", current: "98")
        app.descendants(matching: .any).matching(identifier: "metricActions.Build Success").firstMatch.click()
        app.menuItems["Move Up"].click()
        let first = app.buttons["Edit metric Build Success"]
        let second = app.buttons["Edit metric Latency"]
        XCTAssertLessThan(first.frame.minY, second.frame.minY)
        app.buttons["saveReport"].click()
        waitForSave(app)
        app.buttons["workspaceBack"].click()
        XCTAssertTrue(app.buttons["Open Titan"].waitForExistence(timeout: 5))
        app.buttons["Open Titan"].click()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertLessThan(first.frame.minY, second.frame.minY)

        first.click()
        let current = app.textFields["metricCurrentValue"]
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        XCTAssertEqual(current.value as? String, "98.0")
        current.click()
        current.typeKey("a", modifierFlags: .command)
        current.typeText("99")
        app.buttons["saveMetric"].click()
        app.buttons["saveReport"].click()
        waitForSave(app)
        app.descendants(matching: .any).matching(identifier: "metricActions.Build Success").firstMatch.click()
        app.menuItems["Delete Metric"].click()
        XCTAssertFalse(first.exists)
        XCTAssertTrue(app.buttons["saveReport"].isEnabled)
        app.buttons["discardReport"].click()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.click()
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        XCTAssertEqual(current.value as? String, "99.0")
        app.buttons["cancelMetric"].click()
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
    }

    func testMetricValidationAndCancelDoNotChangeReport() {
        let app = openReport()
        app.buttons["addMetric"].click()
        let name = app.textFields["metricName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveMetric"].isEnabled)
        name.click()
        name.typeText("Latency")
        let current = app.textFields["metricCurrentValue"]
        current.click()
        current.typeText("NaN")
        XCTAssertFalse(app.buttons["saveMetric"].isEnabled)
        current.typeKey("a", modifierFlags: .command)
        current.typeText("120")
        app.checkBoxes["metricHasTarget"].click()
        XCTAssertFalse(app.buttons["saveMetric"].isEnabled)
        app.buttons["cancelMetric"].click()
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
        XCTAssertTrue(app.staticTexts["No metrics yet"].exists)
        addMetric(in: app, name: "Latency", current: "120")
        app.buttons["addMetric"].click()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText(" LATENCY ")
        current.click()
        current.typeText("100")
        XCTAssertFalse(app.buttons["saveMetric"].isEnabled)
        XCTAssertTrue(app.staticTexts["Metric names must be unique in this report."].exists)
        app.buttons["cancelMetric"].click()
        app.buttons["workspaceBack"].click()
        XCTAssertTrue(app.buttons["leaveCancel"].waitForExistence(timeout: 5))
        app.buttons["leaveCancel"].click()
        XCTAssertTrue(app.buttons["Edit metric Latency"].exists)
        app.buttons["discardReport"].click()
        XCTAssertTrue(app.staticTexts["No metrics yet"].exists)
    }

    private func addMetric(in app: XCUIApplication, name: String, current: String) {
        app.buttons["addMetric"].click()
        let field = app.textFields["metricName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText(name)
        app.textFields["metricCurrentValue"].click()
        app.textFields["metricCurrentValue"].typeText(current)
        app.buttons["saveMetric"].click()
        XCTAssertTrue(app.buttons["Edit metric " + name].waitForExistence(timeout: 5))
    }

    private func waitForSave(_ app: XCUIApplication) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == false"), object: app.buttons["saveReport"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
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
        app.popUpButtons["newProjectLineOfBusiness"].click()
        app.menuItems["iPhone"].click()
        app.buttons["Create & Open"].click()
        XCTAssertTrue(app.textFields["reportCodeName"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["addMetric"].waitForExistence(timeout: 5))
        return app
    }
}
