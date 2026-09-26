import XCTest

@MainActor
final class ReportWorkspaceUITests: XCTestCase {
    func testSaveReopenAndDiscard() throws {
        let app = try openNewReport()
        let name = app.textFields["reportCodeName"]
        let save = app.buttons["saveReport"]
        XCTAssertFalse(save.isEnabled)
        XCTAssertFalse(app.staticTexts["Unsaved Changes"].exists)
        XCTAssertFalse(app.staticTexts["Template"].exists)
        XCTAssertFalse(app.staticTexts["Template is read-only"].exists)

        replaceText(in: name, with: "Titan Updated")
        app.popUpButtons["reportLineOfBusiness"].click()
        app.menus.containing(.menuItem, identifier: "iPhone").menuItems["Services"].click()
        XCTAssertTrue(save.isEnabled)
        save.click()
        waitUntilDisabled(save)
        XCTAssertFalse(app.staticTexts["Unsaved Changes"].exists)
        app.buttons["workspaceBack"].click()
        let card = app.buttons["Open Titan Updated"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.click()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Titan Updated")
        XCTAssertEqual(app.popUpButtons["reportLineOfBusiness"].value as? String, "Services")
        replaceText(in: name, with: "Discard this")
        app.buttons["discardReport"].click()
        XCTAssertEqual(name.value as? String, "Titan Updated")
        XCTAssertFalse(save.isEnabled)
    }

    func testLeavingProtectsEditsAcrossNavigationEntrances() throws {
        let app = try openNewReport()
        let name = app.textFields["reportCodeName"]
        replaceText(in: name, with: "Keep editing")
        app.buttons["workspaceBack"].click()
        let cancel = app.buttons["leaveCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.click()
        XCTAssertEqual(name.value as? String, "Keep editing")

        app.typeKey("o", modifierFlags: .command)
        let discard = app.buttons["leaveDiscard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.click()
        let original = app.buttons["Open Titan"]
        XCTAssertTrue(original.waitForExistence(timeout: 5))
        original.click()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Titan")
        replaceText(in: name, with: "Saved before leaving")
        app.typeKey("n", modifierFlags: .command)
        let save = app.buttons["leaveSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["newProjectCodeName"].exists)
        save.click()
        XCTAssertTrue(app.textFields["newProjectCodeName"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].click()
        XCTAssertTrue(app.buttons["Open Saved before leaving"].waitForExistence(timeout: 5))
    }

    func testInvalidDraftCannotSaveOrLeaveWithSave() throws {
        let app = try openNewReport()
        let name = app.textFields["reportCodeName"]
        replaceText(in: name, with: " ")
        XCTAssertTrue(app.staticTexts["Enter a project code name."].exists)
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
        app.buttons["workspaceBack"].click()
        let save = app.buttons["leaveSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.click()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Correct the highlighted fields before saving."].exists)
        app.buttons["discardReport"].click()
        XCTAssertEqual(name.value as? String, "Titan")
        let phase = app.textFields["reportMilestonePhase"]
        phase.click()
        phase.typeText("DVT")
        XCTAssertFalse(app.buttons["saveReport"].isEnabled)
        XCTAssertTrue(app.staticTexts["Provide both a milestone phase and deadline, or clear both."].exists)
    }

    private func openNewReport() throws -> XCUIApplication {
        let app = XCUIApplication.isolated()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        let newProject = app.buttons["newProjectButton"]
        XCTAssertTrue(newProject.waitForExistence(timeout: 10))
        newProject.click()
        let name = app.textFields["newProjectCodeName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("Titan")
        let business = app.popUpButtons["newProjectLineOfBusiness"]
        business.click()
        app.menus.containing(.menuItem, identifier: "iPhone").menuItems["Services"].click()
        app.buttons["Create & Open"].click()
        XCTAssertTrue(app.textFields["reportCodeName"].waitForExistence(timeout: 5))
        return app
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(text)
    }

    private func waitUntilDisabled(_ button: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
