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

    func testLaunchAimIsSymmetricalClampedAndSpeedNormalized() {
        let origin = CGPoint(x: 600, y: 100)
        let left = LaunchAim.angle(from: origin, to: CGPoint(x: 420, y: 320))
        let right = LaunchAim.angle(from: origin, to: CGPoint(x: 780, y: 320))
        XCTAssertEqual(left, -right, accuracy: 0.0001)

        let clamped = LaunchAim.angle(from: origin, to: CGPoint(x: 5_000, y: 101))
        XCTAssertEqual(clamped, LaunchAim.maximumAngle, accuracy: 0.0001)

        let velocity = LaunchAim.velocity(speed: 523, angle: right)
        XCTAssertEqual(hypot(velocity.dx, velocity.dy), 523, accuracy: 0.001)
        XCTAssertGreaterThan(velocity.dy, 0)
    }

    func testRoomSpeedProgressesSmoothlyAndCapsSafely() {
        XCTAssertEqual(BallPhysics.progressiveSpeed(base: 430, completion: 0), 430, accuracy: 0.001)
        XCTAssertEqual(BallPhysics.progressiveSpeed(base: 430, completion: 0.5), 460.1, accuracy: 0.001)
        XCTAssertEqual(BallPhysics.progressiveSpeed(base: 430, completion: 1), 490.2, accuracy: 0.001)
        XCTAssertEqual(BallPhysics.progressiveSpeed(base: 900, completion: 1), BallPhysics.maximumSpeed)

        let next = BallPhysics.approach(430, target: 500, deltaTime: 0.5)
        XCTAssertEqual(next, 443, accuracy: 0.001)
        XCTAssertLessThan(next, 500)
    }

    func testVelocityCorrectionPreservesSpeedAndAvoidsFlatLoops() {
        let corrected = BallPhysics.normalizedVelocity(CGVector(dx: -900, dy: 1), speed: 610)
        XCTAssertEqual(hypot(corrected.dx, corrected.dy), 610, accuracy: 0.001)
        XCTAssertLessThan(corrected.dx, 0)
        XCTAssertGreaterThanOrEqual(abs(corrected.dy), 610 * BallPhysics.minimumVerticalRatio - 0.001)

        let recovered = BallPhysics.normalizedVelocity(.zero, speed: 520)
        XCTAssertEqual(hypot(recovered.dx, recovered.dy), 520, accuracy: 0.001)
        XCTAssertGreaterThan(recovered.dy, 0)
    }

    func testPaddleBounceIsSymmetricAndAlwaysRises() {
        let left = BallPhysics.paddleBounce(offset: -0.75, speed: 580)
        let right = BallPhysics.paddleBounce(offset: 0.75, speed: 580)
        XCTAssertEqual(left.dx, -right.dx, accuracy: 0.001)
        XCTAssertEqual(left.dy, right.dy, accuracy: 0.001)
        XCTAssertEqual(hypot(left.dx, left.dy), 580, accuracy: 0.001)
        XCTAssertGreaterThan(left.dy, 0)
    }
}
