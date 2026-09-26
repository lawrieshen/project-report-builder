import XCTest

extension XCUIApplication {
    /// Keep UI test data separate from real projects while preserving it across relaunches.
    static func isolated() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["PROJECT_REPORT_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["PROJECT_REPORT_MANUAL_SAVE"] = "1"
        return app
    }
}
