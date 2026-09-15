import AppKit
import SpriteKit

final class BrickNode: SKShapeNode {
    var hitPoints: Int
    let maximumHitPoints: Int
    let baseColor: NSColor
    let scoreWeight: Int
    let shape: BrickShape
    let affinity: BrickAffinity
    let role: BrickRole
    let visualTier: Int
    private let durabilityLabel = SKLabelNode()
    private let skinNode: SKSpriteNode
    private var lastAcceptedHitTime = -TimeInterval.greatestFiniteMagnitude

    init(size: CGSize, color: NSColor, hitPoints: Int, shape: BrickShape = .rounded, affinity: BrickAffinity = .quiet, role: BrickRole = .breakable, visualTier: Int = 0, roomVariant: Int = 0) {
        self.hitPoints = hitPoints
        maximumHitPoints = hitPoints
        self.shape = shape
        self.affinity = affinity
        self.role = role
        self.visualTier = min(3, max(0, visualTier))
        let sunColor = NSColor(calibratedRed: 1, green: 0.78, blue: 0.08, alpha: 1)
        baseColor = role == .obstacle ? NSColor(calibratedRed: 0.055, green: 0.07, blue: 0.12, alpha: 1) : (affinity == .sun ? sunColor : color)
        scoreWeight = hitPoints
        skinNode = SKSpriteNode(texture: SKTexture(imageNamed: BrickArtwork.assetName(for: shape, role: role)))
        super.init()
        isAccessibilityElement = false
        path = BrickGeometry.path(for: shape, size: size)
        fillColor = baseColor.withAlphaComponent(role == .obstacle ? 0.82 : 0.32)
        strokeColor = role == .obstacle ? NSColor(calibratedRed: 0.15, green: 0.9, blue: 1, alpha: 1) : (affinity == .sun ? .white : color)
        lineWidth = role == .obstacle ? 1.8 : (affinity == .sun ? 2.2 : 1.35)
        glowWidth = role == .obstacle ? 3.5 : (affinity == .sun ? 6 : 2.5)
        physicsBody = BrickGeometry.physicsBody(for: shape, size: size)
        physicsBody?.isDynamic = false
        physicsBody?.categoryBitMask = role == .obstacle ? PhysicsCategory.obstacle : (affinity == .sun ? PhysicsCategory.sunBrick : PhysicsCategory.brick)
        physicsBody?.collisionBitMask = PhysicsCategory.ball
        physicsBody?.contactTestBitMask = PhysicsCategory.ball
        name = role == .obstacle ? "obstacle" : "brick"

        let artworkCrop = SKCropNode()
        artworkCrop.name = "artwork"
        artworkCrop.isAccessibilityElement = false
        let artworkMask = SKShapeNode(path: BrickGeometry.path(for: shape, size: size))
        artworkMask.isAccessibilityElement = false
        artworkMask.fillColor = .white
        artworkMask.strokeColor = .clear
        artworkCrop.maskNode = artworkMask
        artworkCrop.zPosition = 1
        skinNode.name = "skin"
        skinNode.isAccessibilityElement = false
        skinNode.size = CGSize(width: size.width * 1.06, height: size.height * 1.12)
        skinNode.color = affinity == .sun ? sunColor : color
        skinNode.colorBlendFactor = affinity == .sun ? 0.58 : CGFloat(0.08 + Double(self.visualTier) * 0.06)
        skinNode.alpha = role == .obstacle ? 0.96 : 0.90
        artworkCrop.addChild(skinNode)
        addChild(artworkCrop)

        let innerEdge = SKShapeNode(path: BrickGeometry.path(for: shape, size: CGSize(width: size.width * 0.82, height: size.height * 0.68)))
        innerEdge.isAccessibilityElement = false
        innerEdge.fillColor = .clear
        innerEdge.strokeColor = strokeColor.withAlphaComponent(role == .obstacle ? 0.22 : 0.12)
        innerEdge.lineWidth = visualTier >= 2 ? 1.2 : 0.7
        innerEdge.zPosition = 2
        addChild(innerEdge)

        if self.visualTier > 0 {
            addTierDetails(size: size, roomVariant: roomVariant)
        }

        if role == .breakable, affinity == .sun {
            let sun = SKLabelNode(text: "☀")
            sun.name = "sun-mark"
            sun.isAccessibilityElement = false
            sun.fontName = "AvenirNext-Heavy"
            sun.fontSize = max(12, min(18, size.height * 0.48))
            sun.fontColor = NSColor(calibratedWhite: 0.16, alpha: 0.88)
            sun.verticalAlignmentMode = .center
            sun.position.y = -1
            sun.zPosition = 2
            addChild(sun)
        }

        durabilityLabel.name = "durability"
        durabilityLabel.isAccessibilityElement = false
        durabilityLabel.fontName = "AvenirNext-Heavy"
        durabilityLabel.fontSize = 8
        durabilityLabel.fontColor = affinity == .sun ? .black.withAlphaComponent(0.65) : .white.withAlphaComponent(0.82)
        durabilityLabel.horizontalAlignmentMode = .right
        durabilityLabel.verticalAlignmentMode = .bottom
        durabilityLabel.position = CGPoint(x: size.width * 0.40, y: -size.height * 0.38)
        durabilityLabel.zPosition = 3
        if role == .breakable { addChild(durabilityLabel) }
        updateDurabilityLabel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func takeHit(at time: TimeInterval) -> Bool? {
        guard role == .breakable else { return false }
        guard time - lastAcceptedHitTime >= 0.045 else { return nil }
        lastAcceptedHitTime = time
        hitPoints -= 1
        if hitPoints > 0 {
            fillColor = baseColor.blended(withFraction: 0.48, of: .white) ?? baseColor
            skinNode.alpha = max(0.52, skinNode.alpha - 0.16)
            skinNode.colorBlendFactor = min(0.76, skinNode.colorBlendFactor + 0.14)
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

    private func addTierDetails(size: CGSize, roomVariant: Int) {
        let detail = SKShapeNode()
        detail.isAccessibilityElement = false
        let detailPath = CGMutablePath()
        let insetX = size.width * (visualTier == 1 ? 0.28 : 0.34)
        let insetY = size.height * 0.27
        if visualTier == 1 {
            detailPath.move(to: CGPoint(x: -insetX, y: 0))
            detailPath.addLine(to: CGPoint(x: insetX, y: 0))
        } else if visualTier == 2 {
            detailPath.move(to: CGPoint(x: -insetX, y: insetY))
            detailPath.addLine(to: CGPoint(x: -insetX * 0.48, y: 0))
            detailPath.addLine(to: CGPoint(x: -insetX, y: -insetY))
            detailPath.move(to: CGPoint(x: insetX, y: insetY))
            detailPath.addLine(to: CGPoint(x: insetX * 0.48, y: 0))
            detailPath.addLine(to: CGPoint(x: insetX, y: -insetY))
        } else {
            let direction: CGFloat = roomVariant.isMultiple(of: 2) ? 1 : -1
            detailPath.move(to: CGPoint(x: -insetX, y: -insetY * direction))
            detailPath.addLine(to: CGPoint(x: 0, y: insetY * direction))
            detailPath.addLine(to: CGPoint(x: insetX, y: -insetY * direction))
        }
        detail.path = detailPath
        detail.strokeColor = strokeColor.withAlphaComponent(role == .obstacle ? 0.42 : 0.32)
        detail.lineWidth = 0.9
        detail.glowWidth = visualTier == 3 ? 2 : 0
        detail.zPosition = 2.4
        addChild(detail)
    }
}

enum BrickArtwork {
    static func assetName(for shape: BrickShape, role: BrickRole) -> String {
        if role == .obstacle { return "NeonBrickObstacle" }
        switch shape {
        case .rounded: return "NeonBrickRounded"
        case .capsule: return "NeonBrickCapsule"
        case .diamond: return "NeonBrickDiamond"
        case .hexagon: return "NeonBrickHexagon"
        case .triangle: return "NeonBrickTriangle"
        }
    }
}

enum BrickGeometry {
    static func path(for shape: BrickShape, size: CGSize) -> CGPath {
        let width = size.width
        let height = size.height
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)

        switch shape {
        case .rounded:
            let radius = min(width / 2, min(9, height * 0.28))
            let diagonal = radius * 0.293
            return polygonPath([
                CGPoint(x: rect.minX + radius, y: rect.maxY),
                CGPoint(x: rect.maxX - radius, y: rect.maxY),
                CGPoint(x: rect.maxX - diagonal, y: rect.maxY - diagonal),
                CGPoint(x: rect.maxX, y: rect.maxY - radius),
                CGPoint(x: rect.maxX, y: rect.minY + radius),
                CGPoint(x: rect.maxX - diagonal, y: rect.minY + diagonal),
                CGPoint(x: rect.maxX - radius, y: rect.minY),
                CGPoint(x: rect.minX + radius, y: rect.minY),
                CGPoint(x: rect.minX + diagonal, y: rect.minY + diagonal),
                CGPoint(x: rect.minX, y: rect.minY + radius),
                CGPoint(x: rect.minX, y: rect.maxY - radius),
                CGPoint(x: rect.minX + diagonal, y: rect.maxY - diagonal)
            ])
        case .capsule:
            let radius = min(width / 2, height / 2)
            let diagonal = radius * 0.707
            let leftCenter = rect.minX + radius
            let rightCenter = rect.maxX - radius
            return polygonPath([
                CGPoint(x: leftCenter, y: rect.maxY),
                CGPoint(x: rightCenter, y: rect.maxY),
                CGPoint(x: rightCenter + diagonal, y: diagonal),
                CGPoint(x: rect.maxX, y: 0),
                CGPoint(x: rightCenter + diagonal, y: -diagonal),
                CGPoint(x: rightCenter, y: rect.minY),
                CGPoint(x: leftCenter, y: rect.minY),
                CGPoint(x: leftCenter - diagonal, y: -diagonal),
                CGPoint(x: rect.minX, y: 0),
                CGPoint(x: leftCenter - diagonal, y: diagonal)
            ])
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
        SKPhysicsBody(polygonFrom: path(for: shape, size: size))
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
    static let obstacle: UInt32 = 1 << 7
}
