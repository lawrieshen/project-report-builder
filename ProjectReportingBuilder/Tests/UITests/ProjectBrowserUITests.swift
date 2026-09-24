import XCTest

final class ProjectBrowserUITests: XCTestCase {
    @MainActor
    func testCreateSearchAndOpenProject() throws {
        let app = XCUIApplication()
        // Start with a fresh window instead of restoring a previously closed one.
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        let newProject = app.buttons["newProjectButton"]
        guard newProject.waitForExistence(timeout: 10) else {
            XCTFail(app.debugDescription)
            return
        }
        newProject.click()

        let name = app.textFields["newProjectCodeName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("Titan")
        let business = app.textFields["newProjectLineOfBusiness"]
        business.click()
        business.typeText("Camera")
        app.buttons["Create"].click()

        let card = app.buttons["Open Titan"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let search = app.textFields["Search projects"]
        search.click()
        search.typeText("does not exist")
        XCTAssertTrue(app.buttons["Clear Search"].waitForExistence(timeout: 5))
        XCTAssertFalse(card.exists)
        app.buttons["Clear Search"].click()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.click()
        XCTAssertTrue(app.staticTexts["Report Editor is not available yet."].waitForExistence(timeout: 5))
        // Sidebar navigation returns from the editor to the browser.
        let projectsNavigation = app.buttons["projectsNavigation"]
        XCTAssertTrue(projectsNavigation.exists)
        projectsNavigation.click()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(search.exists)
    }
    @MainActor
    func testFilterAndDeleteProject() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        let newProject = app.buttons["newProjectButton"]
        XCTAssertTrue(newProject.waitForExistence(timeout: 10))
        newProject.click()
        let name = app.textFields["newProjectCodeName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("Atlas")
        let business = app.textFields["newProjectLineOfBusiness"]
        business.click()
        business.typeText("Services")
        app.buttons["Create"].click()

        let card = app.buttons["Open Atlas"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.buttons["projectFilterButton"].click()
        let blocked = app.checkBoxes["Blocked"]
        XCTAssertTrue(blocked.waitForExistence(timeout: 5))
        blocked.click()
        app.buttons["Done"].click()
        XCTAssertTrue(app.buttons["Clear Filters"].waitForExistence(timeout: 5))
        XCTAssertFalse(card.exists)
        app.buttons["Clear Filters"].click()
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
