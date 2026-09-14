import AppKit
import SpriteKit

final class BrickNode: SKShapeNode {
    var hitPoints: Int
    let maximumHitPoints: Int
    let baseColor: NSColor
    let scoreWeight: Int
    let shape: BrickShape
    let affinity: BrickAffinity
    private let durabilityLabel = SKLabelNode()

    init(size: CGSize, color: NSColor, hitPoints: Int, shape: BrickShape = .rounded, affinity: BrickAffinity = .quiet) {
        self.hitPoints = hitPoints
        maximumHitPoints = hitPoints
        self.shape = shape
        self.affinity = affinity
        let sunColor = NSColor(calibratedRed: 1, green: 0.78, blue: 0.08, alpha: 1)
        baseColor = affinity == .sun ? sunColor : color
        scoreWeight = hitPoints
        super.init()
        path = BrickGeometry.path(for: shape, size: size)
        fillColor = baseColor
        strokeColor = affinity == .sun ? NSColor.white : (baseColor.blended(withFraction: 0.34, of: .white) ?? .white)
        lineWidth = affinity == .sun ? 2.8 : 1.6
        glowWidth = affinity == .sun ? 5 : 2
        physicsBody = BrickGeometry.physicsBody(for: shape, size: size)
        physicsBody?.isDynamic = false
        physicsBody?.categoryBitMask = affinity == .sun ? PhysicsCategory.sunBrick : PhysicsCategory.brick
        physicsBody?.collisionBitMask = PhysicsCategory.ball
        physicsBody?.contactTestBitMask = PhysicsCategory.ball
        name = "brick"

        if affinity == .sun {
            let sun = SKLabelNode(text: "☀")
            sun.name = "sun-mark"
            sun.fontName = "AvenirNext-Heavy"
            sun.fontSize = max(12, min(18, size.height * 0.48))
            sun.fontColor = NSColor(calibratedWhite: 0.16, alpha: 0.88)
            sun.verticalAlignmentMode = .center
            sun.position.y = -1
            sun.zPosition = 2
            addChild(sun)
        }

        durabilityLabel.name = "durability"
        durabilityLabel.fontName = "AvenirNext-Heavy"
        durabilityLabel.fontSize = 8
        durabilityLabel.fontColor = affinity == .sun ? .black.withAlphaComponent(0.65) : .white.withAlphaComponent(0.72)
        durabilityLabel.horizontalAlignmentMode = .right
        durabilityLabel.verticalAlignmentMode = .bottom
        durabilityLabel.position = CGPoint(x: size.width * 0.40, y: -size.height * 0.38)
        durabilityLabel.zPosition = 3
        addChild(durabilityLabel)
        updateDurabilityLabel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func takeHit() -> Bool {
        hitPoints -= 1
        if hitPoints > 0 {
            fillColor = baseColor.blended(withFraction: 0.48, of: .white) ?? baseColor
            updateDurabilityLabel()
            run(.sequence([.scale(to: 0.91, duration: 0.04), .scale(to: 1, duration: 0.10)]))
            return false
        }
        physicsBody = nil
        return true
    }

    private func updateDurabilityLabel() {
        durabilityLabel.text = hitPoints > 1 ? String(repeating: "◆", count: min(3, hitPoints)) : ""
    }
}

enum BrickGeometry {
    static func path(for shape: BrickShape, size: CGSize) -> CGPath {
        let width = size.width
        let height = size.height
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)

        switch shape {
        case .rounded:
            return CGPath(roundedRect: rect, cornerWidth: min(9, height * 0.28), cornerHeight: min(9, height * 0.28), transform: nil)
        case .capsule:
            return CGPath(roundedRect: rect, cornerWidth: height / 2, cornerHeight: height / 2, transform: nil)
        case .diamond:
            return polygonPath([
                CGPoint(x: 0, y: height / 2),
                CGPoint(x: -width / 2, y: 0),
                CGPoint(x: 0, y: -height / 2),
                CGPoint(x: width / 2, y: 0)
            ])
        case .hexagon:
            return polygonPath([
                CGPoint(x: -width * 0.34, y: height / 2),
                CGPoint(x: -width / 2, y: 0),
                CGPoint(x: -width * 0.34, y: -height / 2),
                CGPoint(x: width * 0.34, y: -height / 2),
                CGPoint(x: width / 2, y: 0),
                CGPoint(x: width * 0.34, y: height / 2)
            ])
        case .triangle:
            return polygonPath([
                CGPoint(x: 0, y: height / 2),
                CGPoint(x: -width / 2, y: -height / 2),
                CGPoint(x: width / 2, y: -height / 2)
            ])
        }
    }

    static func physicsBody(for shape: BrickShape, size: CGSize) -> SKPhysicsBody {
        switch shape {
        case .rounded, .capsule:
            return SKPhysicsBody(rectangleOf: CGSize(width: size.width - 3, height: size.height - 3))
        case .diamond, .hexagon, .triangle:
            return SKPhysicsBody(polygonFrom: path(for: shape, size: CGSize(width: size.width - 3, height: size.height - 3)))
        }
    }

    private static func polygonPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}

final class PowerUpNode: SKShapeNode {
    let kind: PowerUpKind

    init(kind: PowerUpKind, color: NSColor) {
        self.kind = kind
        super.init()
        path = CGPath(roundedRect: CGRect(x: -20, y: -15, width: 40, height: 30), cornerWidth: 12, cornerHeight: 12, transform: nil)
        fillColor = color
        strokeColor = .white.withAlphaComponent(0.72)
        lineWidth = 2
        glowWidth = 4
        name = "powerup"
        physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 38, height: 28))
        physicsBody?.isDynamic = true
        physicsBody?.affectedByGravity = false
        physicsBody?.velocity = CGVector(dx: 0, dy: -145)
        physicsBody?.categoryBitMask = PhysicsCategory.powerUp
        physicsBody?.collisionBitMask = 0
        physicsBody?.contactTestBitMask = PhysicsCategory.paddle | PhysicsCategory.bottom

        let label = SKLabelNode(text: symbol)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 16
        label.fontColor = NSColor(calibratedWhite: 0.16, alpha: 1)
        label.verticalAlignmentMode = .center
        label.position.y = -1
        addChild(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var symbol: String {
        switch kind {
        case .wide: "↔"
        case .multiball: "●●"
        case .slow: "⌛"
        case .piercing: "✦"
        case .shield: "◇"
        }
    }
}

enum PhysicsCategory {
    static let ball: UInt32 = 1 << 0
    static let paddle: UInt32 = 1 << 1
    static let brick: UInt32 = 1 << 2
    static let wall: UInt32 = 1 << 3
    static let bottom: UInt32 = 1 << 4
    static let powerUp: UInt32 = 1 << 5
    static let sunBrick: UInt32 = 1 << 6
}
