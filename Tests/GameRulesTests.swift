import XCTest
@testable import BreakTheQuietDays

final class GameRulesTests: XCTestCase {
    func testComboMultiplierIncreasesAndCaps() {
        XCTAssertEqual(GameRules.points(forCombo: 0), 100)
        XCTAssertEqual(GameRules.points(forCombo: 4), 200)
        XCTAssertEqual(GameRules.points(forCombo: 16), 500)
        XCTAssertEqual(GameRules.points(forCombo: 99), 500)
    }

    func testDurableBrickWeightsScore() {
        XCTAssertEqual(GameRules.points(forCombo: 0, brickHitPoints: 2), 200)
    }

    func testStarsRequireCompletion() {
        XCTAssertEqual(GameRules.stars(score: 99_999, totalBricks: 30, completed: false), 0)
        XCTAssertEqual(GameRules.stars(score: 3_000, totalBricks: 30, completed: true), 1)
        XCTAssertEqual(GameRules.stars(score: 4_000, totalBricks: 30, completed: true), 2)
        XCTAssertEqual(GameRules.stars(score: 5_700, totalBricks: 30, completed: true), 3)
    }

    func testTimedPowerUpsHaveExpectedDuration() {
        XCTAssertEqual(GameRules.duration(for: .wide), 12)
        XCTAssertEqual(GameRules.duration(for: .slow), 10)
        XCTAssertEqual(GameRules.duration(for: .piercing), 9)
        XCTAssertNil(GameRules.duration(for: .multiball))
        XCTAssertNil(GameRules.duration(for: .shield))
    }

    func testBallAffinityOnlyDamagesTheMatchingBrickFamily() {
        XCTAssertTrue(AffinityRules.canDamage(ballMode: .quiet, brickAffinity: .quiet))
        XCTAssertFalse(AffinityRules.canDamage(ballMode: .quiet, brickAffinity: .sun))
        XCTAssertFalse(AffinityRules.canDamage(ballMode: .sunshift, brickAffinity: .quiet))
        XCTAssertTrue(AffinityRules.canDamage(ballMode: .sunshift, brickAffinity: .sun))
    }

    func testSunshiftTriggersOnlyAfterQuietShapesAreGone() {
        XCTAssertFalse(AffinityRules.shouldTriggerSunshift(quietRemaining: 1, sunRemaining: 4, currentMode: .quiet))
        XCTAssertFalse(AffinityRules.shouldTriggerSunshift(quietRemaining: 0, sunRemaining: 0, currentMode: .quiet))
        XCTAssertTrue(AffinityRules.shouldTriggerSunshift(quietRemaining: 0, sunRemaining: 4, currentMode: .quiet))
        XCTAssertFalse(AffinityRules.shouldTriggerSunshift(quietRemaining: 0, sunRemaining: 4, currentMode: .sunshift))
    }

    func testSunBrickPlacementIsDeterministic() {
        let first = (0..<40).map { AffinityRules.shouldBeSunBrick(index: $0, row: $0 / 8, column: $0 % 8, rate: 0.3) }
        let second = (0..<40).map { AffinityRules.shouldBeSunBrick(index: $0, row: $0 / 8, column: $0 % 8, rate: 0.3) }
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.contains(true))
        XCTAssertTrue(first.contains(false))
    }
}
