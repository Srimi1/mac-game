import Foundation
import SwiftUI

enum AppRoute: Equatable {
    case home
    case daySelect
    case game
    case results
    case settings
    case credits
    case finale
}

enum PowerUpKind: String, Codable, CaseIterable, Sendable {
    case wide
    case multiball
    case slow
    case piercing
    case shield

    var symbol: String {
        switch self {
        case .wide: "arrow.left.and.right"
        case .multiball: "circle.grid.cross"
        case .slow: "tortoise.fill"
        case .piercing: "sparkles"
        case .shield: "shield.fill"
        }
    }

    var title: String { rawValue.capitalized }
}

enum BrickShape: String, Codable, CaseIterable, Hashable, Sendable {
    case rounded
    case capsule
    case diamond
    case hexagon
    case triangle

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .rounded: "rectangle.roundedtop.fill"
        case .capsule: "capsule.fill"
        case .diamond: "diamond.fill"
        case .hexagon: "hexagon.fill"
        case .triangle: "triangle.fill"
        }
    }
}

enum BallMode: String, Codable, Equatable, Sendable {
    case quiet
    case sunshift
}

enum BrickAffinity: String, Codable, Equatable, Sendable {
    case quiet
    case sun
}

enum BrickRole: String, Codable, Equatable, Sendable {
    case breakable
    case obstacle
}

enum MotionAxis: String, Codable, Equatable, Sendable {
    case horizontal
    case vertical
}

struct MotionSpec: Codable, Hashable, Sendable {
    let id: String
    let axis: MotionAxis
    let amplitude: Double
    let duration: Double
    let phase: Double
}

struct BrickPlacement: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let centerX: Double
    let centerY: Double
    let width: Double
    let height: Double
    let rotationDegrees: Double
    let shape: BrickShape
    let role: BrickRole
    let hitPoints: Int
    let affinity: BrickAffinity
    let motionGroup: String?
}

struct LevelLayout: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let placements: [BrickPlacement]
    let motions: [MotionSpec]
}

struct LevelDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let day: Int
    let stage: Int
    let title: String
    let pattern: String
    let rows: Int
    let columns: Int
    let ballSpeed: Double
    let durableEvery: Int
    let movingRows: [Int]
    let powerUpRate: Double
    let shapeMix: [BrickShape]?
    let yellowBrickRate: Double?
    let paddleScale: Double?
    let tripleEvery: Int?
    let layoutID: String?
    let overlayVariant: Int?

    var globalIndex: Int { (day - 1) * 3 + (stage - 1) }
    var brickShapes: [BrickShape] {
        guard let shapeMix, !shapeMix.isEmpty else { return [.rounded] }
        return shapeMix
    }
    var usesSunshift: Bool { (yellowBrickRate ?? 0) > 0 }
    var sunBrickRate: Double { min(0.72, max(0, yellowBrickRate ?? 0)) }
    var resolvedPaddleScale: Double { min(1, max(0.76, paddleScale ?? 1)) }
    var resolvedTripleEvery: Int { max(0, tripleEvery ?? 0) }
    var resolvedLayoutID: String { layoutID ?? id }
    var resolvedOverlayVariant: Int { min(2, max(0, overlayVariant ?? stage - 1)) }

    var difficultyLabel: String {
        switch globalIndex {
        case 0...2: "GENTLE"
        case 3...8: "BRISK"
        case 9...17: "TOUGH"
        default: "FIERCELY COZY"
        }
    }
}

struct DayTheme: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    let brickColors: [Color]
    let backdropAsset: String
    let neonAccent: Color
}

struct GameHUDState: Equatable, Sendable {
    var score = 0
    var lives = 3
    var combo = 0
    var bricksRemaining = 0
    var totalBricks = 0
    var quietBricksRemaining = 0
    var sunBricksRemaining = 0
    var ballMode: BallMode = .quiet
    var sunshiftAvailable = false
    var activePowerUps: [PowerUpKind] = []

    var restoredFraction: Double {
        guard totalBricks > 0 else { return 0 }
        return 1 - Double(bricksRemaining) / Double(totalBricks)
    }
}

struct LevelResult: Equatable, Sendable {
    let levelID: String
    let score: Int
    let stars: Int
    let bestCombo: Int
    let didComplete: Bool
}

struct PlayerSettings: Codable, Equatable, Sendable {
    var musicVolume = 0.32
    var effectsVolume = 0.72
    var reducedMotion = false
    var aimGuide = true
}

struct CampaignProgress: Codable, Equatable, Sendable {
    var highestUnlockedIndex = 0
    var bestScores: [String: Int] = [:]
    var stars: [String: Int] = [:]
    var campaignCompleted = false

    var totalStars: Int { stars.values.reduce(0, +) }
}

enum GameEvent: Sendable {
    case hud(GameHUDState)
    case paused(Bool)
    case completed(LevelResult)
}
