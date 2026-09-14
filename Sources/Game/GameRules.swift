import Foundation

enum GameRules {
    static let startingLives = 3
    static let maximumBalls = 5

    static func points(forCombo combo: Int, brickHitPoints: Int = 1) -> Int {
        let multiplier = min(5, 1 + max(0, combo) / 4)
        return 100 * multiplier * max(1, brickHitPoints)
    }

    static func stars(score: Int, totalBricks: Int, completed: Bool) -> Int {
        guard completed else { return 0 }
        let safeTotal = max(1, totalBricks)
        if score >= safeTotal * 190 { return 3 }
        if score >= safeTotal * 130 { return 2 }
        return 1
    }

    static func duration(for powerUp: PowerUpKind) -> TimeInterval? {
        switch powerUp {
        case .wide: 12
        case .slow: 10
        case .piercing: 9
        case .multiball, .shield: nil
        }
    }
}

enum AffinityRules {
    static func canDamage(ballMode: BallMode, brickAffinity: BrickAffinity) -> Bool {
        switch (ballMode, brickAffinity) {
        case (.quiet, .quiet), (.sunshift, .sun): true
        default: false
        }
    }

    static func shouldBeSunBrick(index: Int, row: Int, column: Int, rate: Double) -> Bool {
        guard rate > 0 else { return false }
        let clampedRate = min(0.72, max(0, rate))
        let deterministicBucket = (index * 37 + row * 11 + column * 17 + 19) % 100
        return Double(deterministicBucket) < clampedRate * 100
    }

    static func shouldTriggerSunshift(quietRemaining: Int, sunRemaining: Int, currentMode: BallMode) -> Bool {
        quietRemaining == 0 && sunRemaining > 0 && currentMode == .quiet
    }
}

enum BrickPattern {
    static func contains(_ pattern: String, row: Int, column: Int, rows: Int, columns: Int) -> Bool {
        let middle = Double(columns - 1) / 2
        let distance = abs(Double(column) - middle)

        switch pattern {
        case "full":
            return true
        case "checker":
            return (row + column) % 2 == 0 || row == 0
        case "pyramid":
            return distance <= Double(row) + 1
        case "waves":
            return (row + (column / 2)) % 3 != 2
        case "frame":
            return row == 0 || row == rows - 1 || column == 0 || column == columns - 1 || (row + column) % 5 == 0
        case "diamond":
            let rowMiddle = Double(rows - 1) / 2
            return distance + abs(Double(row) - rowMiddle) <= min(Double(rows), Double(columns)) * 0.52
        case "staircase":
            return column <= (row + 1) * 2 || column >= columns - 1 - row
        case "garden":
            return row >= 2 || column % 3 == 1 || (row == 1 && column % 2 == 0)
        case "arches":
            return row == 0 || row >= 4 || (column % 4 == 0 || column % 4 == 3)
        case "chevrons":
            return abs(column - columns / 2) == row || abs(column - columns / 2) == max(0, row - 3)
        case "islands":
            return (column / 3 + row / 2) % 2 == 0
        case "wings":
            return distance >= Double(row) * 0.45 || row >= rows - 2
        case "columns":
            return column % 2 == 0 || row == 0 || row == rows - 1
        case "constellation":
            return (row * 7 + column * 3) % 5 < 3 || row == rows - 1
        case "lantern":
            return distance <= Double(columns) * 0.32 + sin(Double(row)) * 1.5 || row == 0
        case "spiral":
            return row == 0 || column == columns - 1 || (row == rows - 1 && column > 1) || (column == 1 && row > 2) || (row == 2 && column < columns - 3)
        case "fortress":
            return row < 2 || row >= rows - 2 || column < 2 || column >= columns - 2 || (row + column) % 4 == 0
        case "finale":
            return (row + column) % 3 != 1 || row == 0 || row == rows - 1
        case "sunburst":
            let rowMiddle = Double(rows - 1) / 2
            return row == rows / 2 || column == columns / 2 || Int(distance + abs(Double(row) - rowMiddle)) % 3 == 0
        case "mosaic":
            return (row * 5 + column * 7) % 9 < 6 || row == 0
        case "hourglass":
            let progress = Double(row) / Double(max(1, rows - 1))
            let allowed = abs(progress - 0.5) * Double(columns) * 0.74 + 1.4
            return distance <= allowed
        case "ribbons":
            return (row + column / 2) % 4 < 2 || row == rows - 1
        case "crown":
            return row >= rows / 2 || row == 0 || (row < rows / 2 && (column % 4 == 0 || column % 4 == 3))
        case "aurora":
            return (row + column) % 4 != 2 || row == 0 || row == rows - 1
        default:
            return true
        }
    }
}
