import XCTest
@testable import BreakTheQuietDays

final class LevelCatalogTests: XCTestCase {
    func testCampaignContainsEightDaysAndTwentyFourLevels() {
        XCTAssertEqual(LevelCatalog.days.count, 8)
        XCTAssertEqual(LevelCatalog.levels.count, 24)
        XCTAssertEqual(LevelCatalog.maximumStars, 72)
        for day in 1...8 {
            XCTAssertEqual(LevelCatalog.levels(for: day).count, 3)
        }
    }

    func testCampaignOrderingAndIdentifiersAreUnique() {
        XCTAssertEqual(Set(LevelCatalog.levels.map(\.id)).count, 24)
        XCTAssertEqual(LevelCatalog.levels.map(\.globalIndex), Array(0..<24))
    }

    func testSunshiftArrivesAfterTheThreeGentleRooms() {
        XCTAssertTrue(LevelCatalog.levels.prefix(3).allSatisfy { !$0.usesSunshift })
        XCTAssertTrue(LevelCatalog.levels.dropFirst(3).allSatisfy(\.usesSunshift))
        XCTAssertGreaterThan(LevelCatalog.levels[3].sunBrickRate, 0)
    }

    func testShapeAndDifficultyVarietyEscalate() {
        XCTAssertEqual(Set(LevelCatalog.levels.flatMap(\.brickShapes)), Set(BrickShape.allCases))
        XCTAssertLessThan(LevelCatalog.levels.last!.resolvedPaddleScale, LevelCatalog.levels.first!.resolvedPaddleScale)
        XCTAssertGreaterThan(LevelCatalog.levels.last!.ballSpeed, LevelCatalog.levels.first!.ballSpeed)
        XCTAssertGreaterThan(LevelCatalog.levels.last!.resolvedTripleEvery, 0)
    }

    func testEveryRoomStartsFasterThanThePreviousRoom() {
        for (current, next) in zip(LevelCatalog.levels, LevelCatalog.levels.dropFirst()) {
            XCTAssertGreaterThan(
                next.ballSpeed,
                current.ballSpeed,
                "Expected \(next.id) to start faster than \(current.id)"
            )
        }
    }
}
