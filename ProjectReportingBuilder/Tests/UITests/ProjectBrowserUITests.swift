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
        XCTAssertTrue(app.buttons["projectsNavigation"].isHittable, "Sidebar before creation")
        newProject.click()

        let name = app.textFields["newProjectCodeName"]
        guard name.waitForExistence(timeout: 5) else {
            XCTFail(app.debugDescription)
            return
        }
        name.click()
        name.typeText("Titan")
        let business = app.textFields["newProjectLineOfBusiness"]
        business.click()
        business.typeText("Camera")
        app.buttons["Create"].click()

        let card = app.buttons["Open Titan"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["projectsNavigation"].isHittable, "Sidebar after creation")
        let search = app.textFields["Search projects"]
        search.click()
        search.typeText("does not exist")
        XCTAssertTrue(app.buttons["Clear Search"].waitForExistence(timeout: 5))
        XCTAssertFalse(card.exists)
        app.buttons["Remove Search: does not exist"].click()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["projectsNavigation"].isHittable, "Sidebar before opening project")
        card.click()
        XCTAssertTrue(app.textFields["reportCodeName"].waitForExistence(timeout: 5))
        // Sidebar navigation returns from the editor to the browser.
        let projectsNavigation = app.buttons["projectsNavigation"]
        let sidebarVisible = NSPredicate(format: "hittable == true")
        let sidebarExpectation = XCTNSPredicateExpectation(predicate: sidebarVisible, object: projectsNavigation)
        guard XCTWaiter.wait(for: [sidebarExpectation], timeout: 5) == .completed else {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
            XCTFail("Sidebar after opening project: " + app.debugDescription)
            return
        }
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
        guard name.waitForExistence(timeout: 5) else {
            XCTFail(app.debugDescription)
            return
        }
        name.click()
        name.typeText("Atlas")
        let business = app.textFields["newProjectLineOfBusiness"]
        business.click()
        business.typeText("Services")
        app.buttons["Create"].click()

        let card = app.buttons["Open Atlas"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.buttons["projectFilterButton"].click()
        let active = app.checkBoxes["Active"]
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        active.click()
        app.checkBoxes["Services"].click()
        app.buttons["Done"].click()
        XCTAssertTrue(app.buttons["Clear Filters"].waitForExistence(timeout: 5))
        XCTAssertFalse(card.exists)
        let search = app.textFields["Search projects"]
        search.click()
        search.typeText("Atlas")
        app.buttons["Remove Status: Active"].click()
        XCTAssertTrue(app.buttons["Remove Search: Atlas"].exists)
        XCTAssertTrue(app.buttons["Remove Line of Business: Services"].exists)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.buttons["Remove Search: Atlas"].click()
        XCTAssertEqual(search.value as? String, "")
        XCTAssertTrue(app.buttons["Remove Line of Business: Services"].exists)
        app.buttons["Remove Line of Business: Services"].click()
        XCTAssertFalse(app.buttons["Remove Line of Business: Services"].exists)
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
