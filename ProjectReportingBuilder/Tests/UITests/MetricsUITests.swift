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

    private func openReport() -> XCUIApplication {
        let app = XCUIApplication()
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
        app.buttons["Create"].click()
        XCTAssertTrue(app.buttons["Open Titan"].waitForExistence(timeout: 5))
        app.buttons["Open Titan"].click()
        XCTAssertTrue(app.buttons["addMetric"].waitForExistence(timeout: 5))
        return app
    }
}
