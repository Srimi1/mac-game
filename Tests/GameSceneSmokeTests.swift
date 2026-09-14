import SpriteKit
import XCTest
@testable import BreakTheQuietDays

@MainActor
final class GameSceneSmokeTests: XCTestCase {
    func testSceneBuildsMovesAndLaunches() throws {
        let level = try XCTUnwrap(LevelCatalog.levels.first)
        var settings = PlayerSettings()
        settings.musicVolume = 0
        settings.effectsVolume = 0
        settings.reducedMotion = true

        let scene = GameScene(level: level, settings: settings) { _ in }
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1_200, height: 760))
        view.presentScene(scene)

        XCTAssertGreaterThan(scene.testingBrickCount, 20)
        XCTAssertEqual(scene.testingBallCount, 1)

        scene.movePaddle(to: 240)
        XCTAssertEqual(scene.testingPaddleX, 240, accuracy: 0.1)

        scene.launchBall()
        let velocity = try XCTUnwrap(scene.testingBallVelocity)
        XCTAssertGreaterThan(velocity.dy, 0)
        XCTAssertGreaterThan(hypot(velocity.dx, velocity.dy), 400)

        view.presentScene(nil)
    }

    func testSunshiftSceneBuildsTwoFamiliesAndChangesBallCollisionTarget() throws {
        let level = try XCTUnwrap(LevelCatalog.levels.first(where: \.usesSunshift))
        var settings = PlayerSettings()
        settings.musicVolume = 0
        settings.effectsVolume = 0
        settings.reducedMotion = true

        let scene = GameScene(level: level, settings: settings) { _ in }
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1_200, height: 760))
        view.presentScene(scene)

        XCTAssertGreaterThan(scene.testingQuietBrickCount, 0)
        XCTAssertGreaterThan(scene.testingSunBrickCount, 0)
        XCTAssertGreaterThan(scene.testingShapeKinds.count, 1)
        XCTAssertEqual(scene.testingBallMode, .quiet)
        XCTAssertNotEqual(scene.testingBallCollisionMask! & PhysicsCategory.brick, 0)
        XCTAssertEqual(scene.testingBallCollisionMask! & PhysicsCategory.sunBrick, 0)

        scene.testingActivateSunshift()
        XCTAssertEqual(scene.testingBallMode, .sunshift)
        XCTAssertEqual(scene.testingBallCollisionMask! & PhysicsCategory.brick, 0)
        XCTAssertNotEqual(scene.testingBallCollisionMask! & PhysicsCategory.sunBrick, 0)
        let sunColor = try XCTUnwrap(scene.testingBallFillColor?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(sunColor.redComponent, 0.95)
        XCTAssertGreaterThan(sunColor.greenComponent, 0.70)
        XCTAssertLessThan(sunColor.blueComponent, 0.20)

        view.presentScene(nil)
    }
}
