import XCTest
@testable import BreakTheQuietDays

final class BrickPatternTests: XCTestCase {
    func testEveryCampaignPatternProducesPlayableWall() {
        let patterns = ["full", "checker", "pyramid", "waves", "frame", "diamond", "staircase", "garden", "arches", "chevrons", "islands", "wings", "columns", "constellation", "lantern", "spiral", "fortress", "finale", "sunburst", "mosaic", "hourglass", "ribbons", "crown", "aurora"]

        for pattern in patterns {
            var count = 0
            for row in 0..<9 {
                for column in 0..<14 where BrickPattern.contains(pattern, row: row, column: column, rows: 9, columns: 14) {
                    count += 1
                }
            }
            XCTAssertGreaterThan(count, 12, "\(pattern) should create a playable wall")
        }
    }

    func testEveryShapeHasAUsableCenteredPath() {
        for shape in BrickShape.allCases {
            let box = BrickGeometry.path(for: shape, size: CGSize(width: 80, height: 32)).boundingBox
            XCTAssertGreaterThan(box.width, 50, "\(shape) should have a wide hit area")
            XCTAssertGreaterThan(box.height, 25, "\(shape) should have a tall hit area")
            XCTAssertEqual(box.midX, 0, accuracy: 0.01)
            XCTAssertEqual(box.midY, 0, accuracy: 0.01)
        }
    }

    func testBrickContactDebouncePreventsDuplicateDamage() {
        let brick = BrickNode(
            size: CGSize(width: 80, height: 32),
            color: .cyan,
            hitPoints: 2
        )
        XCTAssertEqual(brick.takeHit(at: 1), false)
        XCTAssertNil(brick.takeHit(at: 1.02))
        XCTAssertEqual(brick.hitPoints, 1)
        XCTAssertEqual(brick.takeHit(at: 1.06), true)
    }

    func testFullPatternContainsEveryCoordinate() {
        for row in 0..<4 {
            for column in 0..<9 {
                XCTAssertTrue(BrickPattern.contains("full", row: row, column: column, rows: 4, columns: 9))
            }
        }
    }

    func testEveryNeonLayoutIsBoundedPlayableAndInternallyConsistent() {
        for level in LevelCatalog.levels {
            let layout = LevelLayoutFactory.make(for: level)
            let breakables = layout.placements.filter { $0.role == .breakable }
            let obstacles = layout.placements.filter { $0.role == .obstacle }
            let placementIDs = Set(layout.placements.map(\.id))
            let motionIDs = Set(layout.motions.map(\.id))

            XCTAssertEqual(layout.id, level.resolvedLayoutID)
            XCTAssertEqual(placementIDs.count, layout.placements.count, "\(level.id) placement IDs must be unique")
            XCTAssertGreaterThan(breakables.count, 12, "\(level.id) needs a playable target wall")
            XCTAssertLessThanOrEqual(layout.placements.count, LevelLayoutFactory.placementLimit(for: level), "\(level.id) should preserve readable negative space")
            XCTAssertLessThanOrEqual(Double(obstacles.count) / Double(layout.placements.count), 0.15)
            XCTAssertTrue(layout.placements.allSatisfy { (0.03...0.97).contains($0.centerX) && (0.32...0.86).contains($0.centerY) })
            XCTAssertTrue(layout.placements.compactMap(\.motionGroup).allSatisfy(motionIDs.contains))

            if level.usesSunshift {
                XCTAssertTrue(breakables.contains { $0.affinity == .quiet })
                XCTAssertTrue(breakables.contains { $0.affinity == .sun })
            }
            if level.day <= 2 { XCTAssertTrue(obstacles.isEmpty) }
        }

        XCTAssertTrue(LevelCatalog.levels.filter { $0.day >= 3 }.contains {
            LevelLayoutFactory.make(for: $0).placements.contains { $0.role == .obstacle }
        })
    }
}
