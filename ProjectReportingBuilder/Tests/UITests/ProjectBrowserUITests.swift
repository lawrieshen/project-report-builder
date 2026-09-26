import XCTest

final class ProjectBrowserUITests: XCTestCase {
    @MainActor
    func testCreateSearchAndOpenProject() throws {
        let app = XCUIApplication.isolated()
        // Start with a fresh window instead of restoring a previously closed one.
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        let newProject = app.buttons["newProjectButton"]
        guard newProject.waitForExistence(timeout: 10) else {
            XCTFail(app.debugDescription)
            return
        }
        XCTAssertTrue(newProject.isHittable)
        XCTAssertGreaterThan(newProject.frame.midX, app.windows.firstMatch.frame.midX)
        XCTAssertLessThan(newProject.frame.midY, app.windows.firstMatch.frame.midY)
        newProject.click()

        let name = app.textFields["newProjectCodeName"]
        guard name.waitForExistence(timeout: 5) else {
            XCTFail(app.debugDescription)
            return
        }
        // The card stays near the top and its actions follow the compact form.
        XCTAssertLessThan(name.frame.minY, app.windows.firstMatch.frame.midY)
        XCTAssertLessThan(app.buttons["Create & Open"].frame.maxY - name.frame.minY, 220)
        name.click()
        name.typeText("Titan")
        let business = app.textFields["newProjectLineOfBusiness"]
        business.click()
        business.typeText("Camera")
        app.buttons["Create & Open"].click()
        XCTAssertTrue(app.textFields["reportCodeName"].waitForExistence(timeout: 5))
        app.buttons["workspaceBack"].click()

        let card = app.buttons["Open Titan"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(newProject.isHittable)
        let search = app.textFields["Search projects"]
        search.click()
        search.typeText("does not exist")
        XCTAssertTrue(app.buttons["Clear Search"].waitForExistence(timeout: 5))
        XCTAssertFalse(card.exists)
        app.buttons["Remove Search: does not exist"].click()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(newProject.isHittable)
        card.click()
        XCTAssertTrue(app.textFields["reportCodeName"].waitForExistence(timeout: 5))
        // The workspace header returns to the browser without a sidebar.
        let back = app.buttons["workspaceBack"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertTrue(back.isHittable)
        back.click()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(search.exists)
    }
    @MainActor
    func testFilterAndDeleteProject() throws {
        let app = XCUIApplication.isolated()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        let newProject = app.buttons["newProjectButton"]
        XCTAssertTrue(newProject.waitForExistence(timeout: 10))
        newProject.click()
        let name = app.textFields["newProjectCodeName"]
        guard name.waitForExistence(timeout: 5) else {
            XCTFail(app.debugDescription)
            return
        }
        name.click()
        name.typeText("Atlas")
        let business = app.textFields["newProjectLineOfBusiness"]
        business.click()
        business.typeText("Services")
        app.buttons["Create & Open"].click()
        XCTAssertTrue(app.textFields["reportCodeName"].waitForExistence(timeout: 5))
        app.buttons["workspaceBack"].click()

        let card = app.buttons["Open Atlas"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.buttons["projectFilterStatusButton"].click()
        let active = app.checkBoxes["Active"]
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        active.click()
        app.buttons["Done"].click()
        app.buttons["projectFilterBusinessButton"].click()
        XCTAssertTrue(app.checkBoxes["Services"].waitForExistence(timeout: 5))
        app.checkBoxes["Services"].click()
        app.buttons["Done"].click()
        XCTAssertTrue(app.buttons["Clear Filters"].waitForExistence(timeout: 5))
        XCTAssertFalse(card.exists)
        let search = app.textFields["Search projects"]
        search.click()
        search.typeText("Atlas")
        XCTAssertEqual(app.buttons["projectFilterStatusButton"].label, "Status: Active")
        XCTAssertEqual(app.buttons["projectFilterBusinessButton"].label, "Business: Services")
        app.buttons["projectFilterStatusButton"].click()
        app.buttons["Clear"].click()
        app.buttons["Done"].click()
        XCTAssertEqual(app.buttons["projectFilterStatusButton"].label, "Status")
        XCTAssertEqual(search.value as? String, "Atlas")
        XCTAssertEqual(app.buttons["projectFilterBusinessButton"].label, "Business: Services")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        search.click()
        search.typeKey("a", modifierFlags: .command)
        search.typeKey(.delete, modifierFlags: [])
        app.buttons["projectFilterBusinessButton"].click()
        app.buttons["Clear"].click()
        app.buttons["Done"].click()
        XCTAssertEqual(app.buttons["projectFilterBusinessButton"].label, "Business")
        XCTAssertTrue(card.waitForExistence(timeout: 5))

        card.rightClick()
        app.windows.menuItems["Delete"].click()
        let confirmDelete = app.sheets.buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.click()
        XCTAssertTrue(app.staticTexts["No projects yet"].waitForExistence(timeout: 5))
        XCTAssertFalse(card.exists)
    }

}
