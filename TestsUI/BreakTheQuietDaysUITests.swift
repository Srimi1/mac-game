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
        XCTAssertTrue(app.switches["Trajectory Preview, Extend the adjustable neon launch arrow"].exists || app.switches["Trajectory Preview"].exists)
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

    func testGameBoardSupportsDragToAimAndLaunch() {
        let app = launchApp(extraArguments: ["--unlock-all"])
        XCTAssertTrue(app.buttons["Choose a Day"].waitForExistence(timeout: 4))
        app.buttons["Choose a Day"].click()
        let firstRoom = app.buttons["level-day1-1"]
        XCTAssertTrue(firstRoom.waitForExistence(timeout: 3))
        firstRoom.click()

        let board = app.otherElements["game-board"]
        XCTAssertTrue(board.waitForExistence(timeout: 3))
        let ball = board.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.86))
        let target = board.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.55))
        ball.press(forDuration: 0.12, thenDragTo: target)
        XCTAssertEqual(board.value as? String, "Ball launched")
    }
}
