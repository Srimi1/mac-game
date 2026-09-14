import XCTest

@MainActor
final class BreakTheQuietDaysUITests: XCTestCase {
    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"] + extraArguments
        app.launch()
        return app
    }

    func testHomeScreenOpensCampaign() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Choose a Day"].waitForExistence(timeout: 4))
        app.buttons["Choose a Day"].click()
        XCTAssertTrue(app.staticTexts["The Quiet Days"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Morning Room"].exists)
    }

    func testSettingsCanBeOpenedAndClosed() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 4))
        app.buttons["Settings"].click()
        XCTAssertTrue(app.staticTexts["Tune the room to your liking"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["Aim guide, Show the launch direction"].exists || app.switches["Aim guide"].exists)
        app.buttons["Back"].click()
        XCTAssertTrue(app.buttons["Begin the First Day"].waitForExistence(timeout: 2))
    }

    func testSunshiftRoomShowsTwoPhaseOnboarding() {
        let app = launchApp(extraArguments: ["--unlock-all"])
        XCTAssertTrue(app.buttons["Choose a Day"].waitForExistence(timeout: 4))
        app.buttons["Choose a Day"].click()

        let sunshiftRoom = app.buttons["level-day2-1"]
        XCTAssertTrue(sunshiftRoom.waitForExistence(timeout: 3))
        sunshiftRoom.click()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'THEN THE BALL TURNS YELLOW'")).firstMatch.waitForExistence(timeout: 3))
    }
}
