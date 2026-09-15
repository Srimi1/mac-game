import CoreGraphics
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

enum LaunchAim {
    static let maximumAngle = CGFloat.pi / 3
    static let dragThreshold: CGFloat = 14
    static let defaultAngle: CGFloat = 0.34

    static func angle(from origin: CGPoint, to target: CGPoint) -> CGFloat {
        let deltaX = target.x - origin.x
        let deltaY = max(1, target.y - origin.y)
        return min(maximumAngle, max(-maximumAngle, atan2(deltaX, deltaY)))
    }

    static func velocity(speed: CGFloat, angle: CGFloat) -> CGVector {
        let clamped = min(maximumAngle, max(-maximumAngle, angle))
        return CGVector(dx: speed * sin(clamped), dy: speed * cos(clamped))
    }
}

enum BallPhysics {
    static let minimumVerticalRatio: CGFloat = 0.28
    static let maximumRoomIncrease: CGFloat = 0.14
    static let maximumSpeed: CGFloat = 740
    static let accelerationPerSecond: CGFloat = 26

    static func progressiveSpeed(base: CGFloat, completion: Double) -> CGFloat {
        let safeBase = max(1, base)
        let progress = CGFloat(min(1, max(0, completion)))
        return min(maximumSpeed, safeBase * (1 + maximumRoomIncrease * progress))
    }

    static func effectiveSpeed(base: CGFloat, completion: Double, slowed: Bool) -> CGFloat {
        progressiveSpeed(base: base, completion: completion) * (slowed ? 0.72 : 1)
    }

    static func approach(_ current: CGFloat, target: CGFloat, deltaTime: TimeInterval) -> CGFloat {
        let maximumChange = accelerationPerSecond * CGFloat(max(0, deltaTime))
        if current < target { return min(target, current + maximumChange) }
        return max(target, current - maximumChange)
    }

    static func normalizedVelocity(
        _ velocity: CGVector,
        speed: CGFloat,
        minimumVerticalRatio: CGFloat = minimumVerticalRatio
    ) -> CGVector {
        let safeSpeed = min(maximumSpeed, max(1, speed))
        guard velocity.dx.isFinite, velocity.dy.isFinite else {
            return LaunchAim.velocity(speed: safeSpeed, angle: LaunchAim.defaultAngle)
        }

        let magnitude = hypot(velocity.dx, velocity.dy)
        guard magnitude > 0.001 else {
            return LaunchAim.velocity(speed: safeSpeed, angle: LaunchAim.defaultAngle)
        }

        var dx = velocity.dx / magnitude * safeSpeed
        var dy = velocity.dy / magnitude * safeSpeed
        let ratio = min(0.82, max(0.08, minimumVerticalRatio))
        let minimumVertical = safeSpeed * ratio
        if abs(dy) < minimumVertical {
            dy = dy < 0 ? -minimumVertical : minimumVertical
            let horizontal = sqrt(max(0, safeSpeed * safeSpeed - dy * dy))
            dx = dx < 0 ? -horizontal : horizontal
        }
        return CGVector(dx: dx, dy: dy)
    }

    static func paddleBounce(offset: CGFloat, speed: CGFloat) -> CGVector {
        let clampedOffset = min(1, max(-1, offset))
        let angle = clampedOffset * (.pi * 0.34)
        return normalizedVelocity(
            CGVector(dx: sin(angle), dy: cos(angle)),
            speed: speed
        )
    }
}

enum LevelLayoutFactory {
    private static let sceneWidth = 1_200.0
    private static let sceneHeight = 760.0

    static func make(for level: LevelDefinition) -> LevelLayout {
        let availableWidth = 1_040.0
        let gap = 10.0
        let baseWidth = (availableWidth - Double(level.columns - 1) * gap) / Double(level.columns)
        let baseHeight = max(27, min(36, 246 / Double(level.rows)))
        let startX = (sceneWidth - availableWidth) / 2 + baseWidth / 2
        let startY = 620.0
        let movingRows = Set(level.movingRows + extraMovingRows(for: level))
        let coordinates = curatedCoordinates(for: level)
        var placements: [BrickPlacement] = []
        var playableIndex = 0

        for (row, column) in coordinates {
            let rowShift = rowOffset(level: level, row: row, cellWidth: baseWidth + gap)
            let obstacle = shouldPlaceObstacle(level: level, row: row, column: column)
            let triple = !obstacle && level.resolvedTripleEvery > 0 && playableIndex % level.resolvedTripleEvery == 0
            let durable = !obstacle && level.durableEvery > 0 && playableIndex % level.durableEvery == 0
            let hitPoints = obstacle ? 0 : (triple ? 3 : (durable ? 2 : 1))
            let affinity: BrickAffinity = !obstacle && AffinityRules.shouldBeSunBrick(
                index: playableIndex,
                row: row,
                column: column,
                rate: level.sunBrickRate
            ) ? .sun : .quiet
            let shape = level.brickShapes[(row * 3 + column + playableIndex) % level.brickShapes.count]
            let shapeScale = opticalScale(for: shape)
            let centerX = startX + Double(column) * (baseWidth + gap) + rowShift
            let centerY = startY - Double(row) * (baseHeight + gap)
            let rotation = rotationDegrees(level: level, row: row, column: column, shape: shape)
            let motionID = movingRows.contains(row) ? "row-\(row)" : nil

            placements.append(BrickPlacement(
                id: "\(level.resolvedLayoutID)-r\(row)-c\(column)",
                centerX: centerX / sceneWidth,
                centerY: centerY / sceneHeight,
                width: baseWidth * shapeScale.width / sceneWidth,
                height: baseHeight * shapeScale.height / sceneHeight,
                rotationDegrees: rotation,
                shape: obstacle ? .hexagon : shape,
                role: obstacle ? .obstacle : .breakable,
                hitPoints: hitPoints,
                affinity: affinity,
                motionGroup: motionID
            ))
            if !obstacle { playableIndex += 1 }
        }

        let motions = movingRows.sorted().map { row in
            MotionSpec(
                id: "row-\(row)",
                axis: level.day >= 7 && row % 3 == 0 ? .vertical : .horizontal,
                amplitude: row % 2 == 0 ? 22 : -22,
                duration: 1.8 + Double(row % 3) * 0.34,
                phase: Double(row % 4) * 0.16
            )
        }
        return LevelLayout(id: level.resolvedLayoutID, placements: placements, motions: motions)
    }

    static func placementLimit(for level: LevelDefinition) -> Int {
        switch level.day {
        case 1: 52
        case 2: 56
        case 3: 58
        case 4: 60
        default: 64
        }
    }

    private static func curatedCoordinates(for level: LevelDefinition) -> [(Int, Int)] {
        var coordinates: [(Int, Int)] = []
        for row in 0..<level.rows {
            for column in 0..<level.columns where BrickPattern.contains(
                level.pattern,
                row: row,
                column: column,
                rows: level.rows,
                columns: level.columns
            ) {
                coordinates.append((row, column))
            }
        }

        let limit = placementLimit(for: level)
        guard coordinates.count > limit, limit > 1 else { return coordinates }
        let last = coordinates.count - 1
        let selected = Set((0..<limit).map { sample in
            Int((Double(sample) * Double(last) / Double(limit - 1)).rounded())
        })
        return coordinates.enumerated().compactMap { selected.contains($0.offset) ? $0.element : nil }
    }

    private static func rowOffset(level: LevelDefinition, row: Int, cellWidth: Double) -> Double {
        guard level.stage > 1 else { return 0 }
        let direction = (row + level.day + level.stage).isMultiple(of: 2) ? 1.0 : -1.0
        let strength = level.stage == 2 ? 0.12 : 0.20
        return direction * cellWidth * strength
    }

    private static func rotationDegrees(level: LevelDefinition, row: Int, column: Int, shape: BrickShape) -> Double {
        guard level.day >= 3, shape != .capsule, shape != .rounded else { return 0 }
        let bucket = (row * 7 + column * 11 + level.day) % 3
        let direction = Double(bucket - 1)
        let amount = level.day >= 7 ? 5.0 : 3.0
        return direction * amount
    }

    private static func opticalScale(for shape: BrickShape) -> (width: Double, height: Double) {
        switch shape {
        case .rounded: (1, 1)
        case .capsule: (0.96, 0.90)
        case .diamond: (0.88, 0.94)
        case .hexagon: (0.94, 0.96)
        case .triangle: (0.82, 0.94)
        }
    }

    private static func shouldPlaceObstacle(level: LevelDefinition, row: Int, column: Int) -> Bool {
        guard level.day >= 3, row > 0, row < level.rows - 1 else { return false }
        let cadence = level.day <= 4 ? 19 : (level.day <= 6 ? 15 : 12)
        return (row * 13 + column * 7 + level.day * 5 + level.stage * 3) % cadence == 0
    }

    private static func extraMovingRows(for level: LevelDefinition) -> [Int] {
        guard level.day >= 5, level.rows > 4 else { return [] }
        return [(level.day + level.stage * 2) % (level.rows - 2) + 1]
    }
}
