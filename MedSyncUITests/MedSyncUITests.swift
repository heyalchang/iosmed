import XCTest

final class MedSyncUITests: XCTestCase {
    func testAppLaunchShowsShellTabs() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Manual Export"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Automations"].exists)
        XCTAssertTrue(app.tabBars.buttons["Activity Log"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }
}
