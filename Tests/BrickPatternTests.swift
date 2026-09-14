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

    func testFullPatternContainsEveryCoordinate() {
        for row in 0..<4 {
            for column in 0..<9 {
                XCTAssertTrue(BrickPattern.contains("full", row: row, column: column, rows: 4, columns: 9))
            }
        }
    }
}
