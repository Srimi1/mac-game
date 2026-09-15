import AppKit
import GameController
import SpriteKit

@MainActor
final class GameScene: SKScene, @preconcurrency SKPhysicsContactDelegate {
    private let level: LevelDefinition
    private let theme: DayTheme
    private let settings: PlayerSettings
    private let sound: SoundEngine
    private let eventHandler: (GameEvent) -> Void

    private let worldNode = SKNode()
    private let paddle = SKShapeNode(rectOf: CGSize(width: 178, height: 24), cornerRadius: 12)
    private let paddleSkin = SKSpriteNode(imageNamed: "NeonPaddle")
    private let colorWash = SKShapeNode(rectOf: CGSize(width: 1400, height: 900))
    private let aimGuide = SKShapeNode()
    private let cameraNode = SKCameraNode()
    private var hud = GameHUDState()
    private var keyboardDirection: CGFloat = 0
    private var ballIsWaiting = true
    private var isAiming = false
    private var aimOrigin = CGPoint.zero
    private var aimDragDistance: CGFloat = 0
    private var launchAngle = LaunchAim.defaultAngle
    private var desiredBallSpeed: CGFloat
    private var baseBallSpeed: CGFloat
    private var bestCombo = 0
    private var lastUpdateTime: TimeInterval = 0
    private var ambientTime: TimeInterval = 0
    private var ambientStep = 0
    private var controllerMenuWasPressed = false
    private var isFinishing = false
    private var hasShield = false
    private var sunshiftActive = false
    private var sunshiftTransitionQueued = false
    private var activeUntil: [PowerUpKind: TimeInterval] = [:]

    var testingBallCount: Int { activeBalls().count }
    var testingBrickCount: Int {
        var count = 0
        worldNode.enumerateChildNodes(withName: "//brick") { _, _ in count += 1 }
        return count
    }
    var testingObstacleCount: Int {
        var count = 0
        worldNode.enumerateChildNodes(withName: "//obstacle") { _, _ in count += 1 }
        return count
    }
    var testingPaddleX: CGFloat { paddle.position.x }
    var testingBallVelocity: CGVector? { activeBalls().first?.physicsBody?.velocity }
    var testingBallCollisionMask: UInt32? { activeBalls().first?.physicsBody?.collisionBitMask }
    var testingBallFillColor: NSColor? { (activeBalls().first as? SKShapeNode)?.fillColor }
    var testingSunBrickCount: Int { hud.sunBricksRemaining }
    var testingQuietBrickCount: Int { hud.quietBricksRemaining }
    var testingBallMode: BallMode { hud.ballMode }
    var testingLaunchAngle: CGFloat { launchAngle }
    var testingDesiredBallSpeed: CGFloat { desiredBallSpeed }
    var testingTargetBallSpeed: CGFloat { targetBallSpeed }
    var isBallWaiting: Bool { ballIsWaiting }
    var testingPaddleHasArtwork: Bool { paddle.childNode(withName: "paddle-skin") != nil }
    var testingBallHasArtwork: Bool { activeBalls().first?.childNode(withName: "ball-artwork") != nil }
    var testingBrickVisualTiers: Set<Int> {
        var tiers: Set<Int> = []
        worldNode.enumerateChildNodes(withName: "//brick") { node, _ in
            if let brick = node as? BrickNode { tiers.insert(brick.visualTier) }
        }
        return tiers
    }
    var testingShapeKinds: Set<BrickShape> {
        var shapes: Set<BrickShape> = []
        worldNode.enumerateChildNodes(withName: "//brick") { node, _ in
            if let brick = node as? BrickNode { shapes.insert(brick.shape) }
        }
        return shapes
    }
    func testingActivateSunshift() { activateSunshift() }

    init(level: LevelDefinition, settings: PlayerSettings, eventHandler: @escaping (GameEvent) -> Void) {
        self.level = level
        theme = LevelCatalog.theme(for: level.day)
        self.settings = settings
        sound = SoundEngine(settings: settings)
        self.eventHandler = eventHandler
        baseBallSpeed = CGFloat(level.ballSpeed)
        desiredBallSpeed = CGFloat(level.ballSpeed)
        super.init(size: CGSize(width: 1200, height: 760))
        scaleMode = .aspectFill
        anchorPoint = .zero
        worldNode.isAccessibilityElement = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        backgroundColor = NSColor(theme.colors[0])
        addChild(worldNode)
        buildBackground()
        buildBoundaries()
        buildPaddle()
        buildBricks()
        buildAimGuide()
        buildCamera()
        spawnWaitingBall()
        emitHUD()
        // SwiftUI can still be constructing its representable when SpriteKit's
        // first didMove callback fires. Repeat once on the next actor turn so
        // the initial brick totals are never lost by the HUD.
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.emitHUD()
        }
    }

    override func willMove(from view: SKView) {
        sound.stop()
    }

    func movePaddle(to sceneX: CGFloat) {
        guard !isPaused, !isFinishing else { return }
        let halfWidth = paddle.frame.width / 2
        paddle.position.x = min(size.width - 38 - halfWidth, max(38 + halfWidth, sceneX))
        if ballIsWaiting, let ball = worldNode.childNode(withName: "//ball") {
            ball.position.x = paddle.position.x
        }
        updateAimGuide()
    }

    func setKeyboardDirection(_ direction: CGFloat) {
        keyboardDirection = direction
    }

    func launchBall() {
        guard !isPaused, ballIsWaiting, !isFinishing,
              let ball = worldNode.childNode(withName: "//ball") else { return }
        ballIsWaiting = false
        isAiming = false
        aimGuide.isHidden = true
        setPaddleAiming(false)
        ball.physicsBody?.velocity = LaunchAim.velocity(speed: desiredBallSpeed, angle: launchAngle)
        paddleSkin.run(.sequence([.fadeAlpha(to: 1, duration: 0.04), .fadeAlpha(to: 0.88, duration: 0.18)]))
        view?.setAccessibilityValue("Ball launched")
        sound.playPaddle(offset: 0)
    }

    @discardableResult
    func beginAim(at point: CGPoint) -> Bool {
        guard !isPaused, ballIsWaiting, !isFinishing,
              let ball = worldNode.childNode(withName: "//ball"),
              hypot(point.x - ball.position.x, point.y - ball.position.y) <= 58 else { return false }
        isAiming = true
        aimOrigin = ball.position
        aimDragDistance = 0
        setPaddleAiming(true)
        updateAimGuide()
        return true
    }

    func updateAim(to point: CGPoint) {
        guard isAiming, ballIsWaiting else { return }
        aimDragDistance = hypot(point.x - aimOrigin.x, point.y - aimOrigin.y)
        launchAngle = LaunchAim.angle(from: aimOrigin, to: point)
        updateAimGuide()
    }

    func endAimAndLaunch(at point: CGPoint) {
        guard isAiming else { return }
        updateAim(to: point)
        let shouldLaunch = aimDragDistance >= LaunchAim.dragThreshold
        isAiming = false
        if shouldLaunch { launchBall() } else {
            setPaddleAiming(false)
            updateAimGuide()
        }
    }

    func adjustAim(by delta: CGFloat) {
        guard ballIsWaiting, !isPaused, !isFinishing else { return }
        launchAngle = min(LaunchAim.maximumAngle, max(-LaunchAim.maximumAngle, launchAngle + delta))
        updateAimGuide()
    }

    func togglePause() {
        guard !isFinishing else { return }
        isPaused.toggle()
        eventHandler(.paused(isPaused))
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        eventHandler(.paused(paused))
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = min(1.0 / 30.0, max(0, lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime))
        lastUpdateTime = currentTime

        let controllerDirection = CGFloat(GCController.controllers().first?.extendedGamepad?.leftThumbstick.xAxis.value ?? 0)
        let direction = abs(controllerDirection) > 0.12 ? controllerDirection : keyboardDirection
        if direction != 0 {
            movePaddle(to: paddle.position.x + direction * 760 * delta)
        }

        if let gamepad = GCController.controllers().first?.extendedGamepad {
            let aimDirection = CGFloat(gamepad.rightThumbstick.xAxis.value)
            if ballIsWaiting, abs(aimDirection) > 0.14 {
                launchAngle = aimDirection * LaunchAim.maximumAngle
                updateAimGuide()
            }
            if gamepad.buttonA.isPressed, ballIsWaiting { launchBall() }
            let menuPressed = gamepad.buttonMenu.isPressed
            if menuPressed && !controllerMenuWasPressed { togglePause() }
            controllerMenuWasPressed = menuPressed
        }

        expirePowerUps(at: currentTime)
        advanceBallSpeed(deltaTime: delta)
        normalizeBallVelocities()

        ambientTime += delta
        if ambientTime >= 0.95 {
            ambientTime = 0
            ambientStep += 1
            sound.playAmbient(step: ambientStep, restored: hud.restoredFraction, day: level.day)
        }

        for powerUp in worldNode.children.compactMap({ $0 as? PowerUpNode }) where powerUp.position.y < -30 {
            powerUp.removeFromParent()
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let first = contact.bodyA.node
        let second = contact.bodyB.node
        let categories = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        let ballAndQuietBrick = PhysicsCategory.ball | PhysicsCategory.brick
        let ballAndSunBrick = PhysicsCategory.ball | PhysicsCategory.sunBrick
        if categories == ballAndQuietBrick || categories == ballAndSunBrick {
            guard let brick = (first as? BrickNode) ?? (second as? BrickNode),
                  let ball = first?.name == "ball" ? first : second else { return }
            hit(brick: brick, with: ball, at: contact.contactPoint)
        } else if categories == PhysicsCategory.ball | PhysicsCategory.paddle {
            guard let ball = first?.name == "ball" ? first : second else { return }
            bounce(ball: ball)
        } else if categories == PhysicsCategory.ball | PhysicsCategory.bottom {
            guard let ball = first?.name == "ball" ? first : second else { return }
            lose(ball: ball)
        } else if categories == PhysicsCategory.powerUp | PhysicsCategory.paddle {
            guard let powerUp = (first as? PowerUpNode) ?? (second as? PowerUpNode) else { return }
            collect(powerUp)
        } else if categories == PhysicsCategory.powerUp | PhysicsCategory.bottom {
            ((first as? PowerUpNode) ?? (second as? PowerUpNode))?.removeFromParent()
        } else if categories == PhysicsCategory.ball | PhysicsCategory.obstacle {
            impact(at: contact.contactPoint, color: NSColor(calibratedRed: 0.10, green: 0.88, blue: 1, alpha: 1))
        }
    }

    private func buildBackground() {
        let backdrop = SKSpriteNode(texture: SKTexture(imageNamed: theme.backdropAsset))
        backdrop.isAccessibilityElement = false
        backdrop.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backdrop.size = size
        backdrop.alpha = 0.62 + CGFloat(level.resolvedOverlayVariant) * 0.06
        backdrop.zPosition = -120
        worldNode.addChild(backdrop)

        colorWash.fillColor = NSColor(calibratedRed: 0.015, green: 0.02, blue: 0.075, alpha: 0.38 - CGFloat(level.resolvedOverlayVariant) * 0.05)
        colorWash.isAccessibilityElement = false
        colorWash.strokeColor = .clear
        colorWash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        colorWash.zPosition = -110
        worldNode.addChild(colorWash)

        let grid = SKNode()
        grid.isAccessibilityElement = false
        grid.zPosition = -100
        for index in 0..<13 {
            let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 1))
            line.isAccessibilityElement = false
            line.fillColor = NSColor(theme.neonAccent).withAlphaComponent(0.025 + CGFloat(level.resolvedOverlayVariant) * 0.008)
            line.strokeColor = .clear
            line.position = CGPoint(x: size.width / 2, y: 48 + CGFloat(index) * 56)
            grid.addChild(line)
        }
        worldNode.addChild(grid)

        for index in 0..<14 {
            let mote = SKShapeNode(circleOfRadius: CGFloat(2 + index % 3))
            mote.isAccessibilityElement = false
            mote.fillColor = NSColor(theme.brickColors[index % theme.brickColors.count]).withAlphaComponent(0.22)
            mote.strokeColor = .clear
            mote.glowWidth = 5
            mote.position = CGPoint(x: 55 + CGFloat((index * 137) % 1090), y: 88 + CGFloat((index * 97) % 570))
            mote.zPosition = -80
            worldNode.addChild(mote)
            if !settings.reducedMotion {
                let drift = SKAction.moveBy(x: CGFloat((index % 3) - 1) * 18, y: CGFloat(index % 2 == 0 ? 12 : -12), duration: 4.5 + Double(index % 3))
                drift.timingMode = .easeInEaseOut
                mote.run(.repeatForever(.sequence([drift, drift.reversed()])))
            }
        }

        // The SwiftUI HUD owns all text. Keeping SpriteKit text out of this
        // region protects readability at the app's minimum window size.
    }

    private func buildBoundaries() {
        let left = SKNode()
        left.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 32, y: 32), to: CGPoint(x: 32, y: 734))
        let right = SKNode()
        right.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 1168, y: 32), to: CGPoint(x: 1168, y: 734))
        let top = SKNode()
        top.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 32, y: 734), to: CGPoint(x: 1168, y: 734))
        [left, right, top].forEach {
            $0.physicsBody?.categoryBitMask = PhysicsCategory.wall
            $0.physicsBody?.collisionBitMask = PhysicsCategory.ball
            $0.physicsBody?.friction = 0
            $0.physicsBody?.restitution = 1
            worldNode.addChild($0)
        }

        let bottom = SKNode()
        bottom.position = CGPoint(x: 0, y: 8)
        bottom.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 24, y: 0), to: CGPoint(x: 1176, y: 0))
        bottom.physicsBody?.categoryBitMask = PhysicsCategory.bottom
        bottom.physicsBody?.collisionBitMask = 0
        bottom.physicsBody?.contactTestBitMask = PhysicsCategory.ball | PhysicsCategory.powerUp
        worldNode.addChild(bottom)
    }

    private func buildPaddle() {
        paddle.fillColor = NSColor(calibratedRed: 0.018, green: 0.025, blue: 0.07, alpha: 0.68)
        paddle.strokeColor = NSColor(theme.neonAccent).withAlphaComponent(0.42)
        paddle.lineWidth = 1.4
        paddle.glowWidth = 7
        paddle.position = CGPoint(x: size.width / 2, y: 74)
        paddle.xScale = CGFloat(level.resolvedPaddleScale)
        paddle.zPosition = 10
        paddle.name = "paddle"
        paddle.isAccessibilityElement = false
        paddle.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 174, height: 22))
        paddle.physicsBody?.isDynamic = false
        paddle.physicsBody?.categoryBitMask = PhysicsCategory.paddle
        paddle.physicsBody?.collisionBitMask = PhysicsCategory.ball
        paddle.physicsBody?.contactTestBitMask = PhysicsCategory.ball | PhysicsCategory.powerUp
        paddle.physicsBody?.friction = 0
        paddle.physicsBody?.restitution = 1
        paddleSkin.name = "paddle-skin"
        paddleSkin.isAccessibilityElement = false
        paddleSkin.size = CGSize(width: 202, height: 34)
        paddleSkin.alpha = 0.88
        paddleSkin.color = NSColor(theme.neonAccent)
        paddleSkin.colorBlendFactor = CGFloat(level.resolvedOverlayVariant) * 0.06
        paddleSkin.zPosition = 1
        paddle.addChild(paddleSkin)

        let cradle = SKShapeNode(circleOfRadius: 15)
        cradle.name = "launch-cradle"
        cradle.isAccessibilityElement = false
        cradle.position.y = 16
        cradle.fillColor = .clear
        cradle.strokeColor = NSColor(theme.neonAccent).withAlphaComponent(0.52)
        cradle.lineWidth = 1.2
        cradle.glowWidth = 5
        cradle.zPosition = 0
        paddle.addChild(cradle)
        worldNode.addChild(paddle)
    }

    private func buildBricks() {
        let layout = LevelLayoutFactory.make(for: level)
        var quietPlaced = 0
        var sunPlaced = 0
        var containers: [String: SKNode] = [:]

        for motion in layout.motions {
            let node = SKNode()
            node.name = "motion-\(motion.id)"
            node.zPosition = 2
            worldNode.addChild(node)
            containers[motion.id] = node
            guard !settings.reducedMotion else { continue }
            let vector = motion.axis == .horizontal
                ? CGVector(dx: motion.amplitude, dy: 0)
                : CGVector(dx: 0, dy: motion.amplitude)
            let move = SKAction.moveBy(x: vector.dx, y: vector.dy, duration: motion.duration)
            move.timingMode = .easeInEaseOut
            node.run(.sequence([.wait(forDuration: motion.phase), .repeatForever(.sequence([move, move.reversed()]))]))
        }

        for (index, placement) in layout.placements.enumerated() {
            let color = NSColor(theme.brickColors[index % theme.brickColors.count])
            let brick = BrickNode(
                size: CGSize(width: placement.width * size.width, height: placement.height * size.height),
                color: color,
                hitPoints: placement.hitPoints,
                shape: placement.shape,
                affinity: placement.affinity,
                role: placement.role,
                visualTier: (level.day - 1) / 2,
                roomVariant: level.resolvedOverlayVariant
            )
            brick.position = CGPoint(x: placement.centerX * size.width, y: placement.centerY * size.height)
            brick.zRotation = placement.rotationDegrees * .pi / 180
            brick.alpha = placement.role == .obstacle ? 0.96 : (placement.affinity == .sun ? 0.48 : 0.94)
            (placement.motionGroup.flatMap { containers[$0] } ?? worldNode).addChild(brick)
            guard placement.role == .breakable else { continue }
            if placement.affinity == .sun { sunPlaced += 1 } else { quietPlaced += 1 }
        }

        hud.totalBricks = quietPlaced + sunPlaced
        hud.bricksRemaining = hud.totalBricks
        hud.quietBricksRemaining = quietPlaced
        hud.sunBricksRemaining = sunPlaced
        hud.sunshiftAvailable = sunPlaced > 0
        hud.ballMode = .quiet
    }

    private func buildAimGuide() {
        aimGuide.strokeColor = NSColor(theme.neonAccent).withAlphaComponent(0.88)
        aimGuide.isAccessibilityElement = false
        aimGuide.lineWidth = 2.4
        aimGuide.glowWidth = 8
        aimGuide.zPosition = 18
        aimGuide.isHidden = false
        worldNode.addChild(aimGuide)
        updateAimGuide()
    }

    private func updateAimGuide() {
        guard ballIsWaiting, let ball = worldNode.childNode(withName: "//ball") else {
            aimGuide.isHidden = true
            return
        }
        let origin = ball.position
        let direction = CGVector(dx: sin(launchAngle), dy: cos(launchAngle))
        let length: CGFloat = settings.aimGuide || isAiming ? 205 : 76
        let path = CGMutablePath()
        let segment: CGFloat = settings.aimGuide || isAiming ? 16 : length
        var distance: CGFloat = 16
        while distance < length - 13 {
            let endDistance = min(length - 13, distance + segment * 0.58)
            path.move(to: CGPoint(x: origin.x + direction.dx * distance, y: origin.y + direction.dy * distance))
            path.addLine(to: CGPoint(x: origin.x + direction.dx * endDistance, y: origin.y + direction.dy * endDistance))
            distance += segment
        }
        let tip = CGPoint(x: origin.x + direction.dx * length, y: origin.y + direction.dy * length)
        let normal = CGVector(dx: -direction.dy, dy: direction.dx)
        let base = CGPoint(x: tip.x - direction.dx * 15, y: tip.y - direction.dy * 15)
        path.move(to: CGPoint(x: base.x + normal.dx * 8, y: base.y + normal.dy * 8))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: base.x - normal.dx * 8, y: base.y - normal.dy * 8))
        aimGuide.path = path
        aimGuide.isHidden = false
    }

    private func buildCamera() {
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode
    }

    private func spawnWaitingBall() {
        let ball = makeBall(at: CGPoint(x: paddle.position.x, y: 105))
        ball.physicsBody?.velocity = .zero
        worldNode.addChild(ball)
        ballIsWaiting = true
        isAiming = false
        setPaddleAiming(false)
        view?.setAccessibilityValue("Ball waiting")
        updateAimGuide()
    }

    private func makeBall(at point: CGPoint) -> SKShapeNode {
        let ball = SKShapeNode(circleOfRadius: 11)
        ball.name = "ball"
        ball.isAccessibilityElement = false
        ball.lineWidth = 2
        ball.position = point
        ball.zPosition = 20
        ball.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        ball.physicsBody?.isDynamic = true
        ball.physicsBody?.affectedByGravity = false
        ball.physicsBody?.allowsRotation = false
        ball.physicsBody?.angularDamping = 0
        ball.physicsBody?.linearDamping = 0
        ball.physicsBody?.friction = 0
        ball.physicsBody?.restitution = 1
        ball.physicsBody?.mass = 0.012
        ball.physicsBody?.fieldBitMask = 0
        ball.physicsBody?.isResting = false
        ball.physicsBody?.usesPreciseCollisionDetection = true
        ball.physicsBody?.categoryBitMask = PhysicsCategory.ball
        ball.physicsBody?.contactTestBitMask = PhysicsCategory.paddle | PhysicsCategory.brick | PhysicsCategory.sunBrick | PhysicsCategory.obstacle | PhysicsCategory.bottom
        let artwork = SKSpriteNode(imageNamed: "NeonBall")
        artwork.name = "ball-artwork"
        artwork.isAccessibilityElement = false
        artwork.size = CGSize(width: 31, height: 31)
        artwork.zPosition = 1
        ball.addChild(artwork)
        if !settings.reducedMotion {
            artwork.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 1.5)))
        }
        updateBallAppearance(ball)
        updateBallCollisionMask(ball)
        attachTrail(to: ball)
        return ball
    }

    private func attachTrail(to ball: SKNode) {
        guard !settings.reducedMotion else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = particleTexture()
        emitter.particleBirthRate = 40
        emitter.particleLifetime = 0.34
        emitter.particleLifetimeRange = 0.08
        emitter.particleScale = 0.7
        emitter.particleScaleSpeed = -1.8
        emitter.particleAlpha = 0.48
        emitter.particleAlphaSpeed = -1.3
        emitter.name = "ball-trail"
        emitter.particleColor = sunshiftActive ? sunColor : NSColor(theme.brickColors[0])
        emitter.particleColorBlendFactor = 1
        emitter.targetNode = worldNode
        emitter.zPosition = -1
        ball.addChild(emitter)
    }

    private func particleTexture() -> SKTexture {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
        image.unlockFocus()
        return SKTexture(image: image)
    }

    private func hit(brick: BrickNode, with ball: SKNode, at point: CGPoint) {
        guard brick.parent != nil, !isFinishing else { return }
        guard AffinityRules.canDamage(ballMode: hud.ballMode, brickAffinity: brick.affinity) else {
            resistedImpact(at: point, affinity: brick.affinity)
            return
        }
        guard let destroyed = brick.takeHit(at: lastUpdateTime) else { return }
        hud.combo += 1
        bestCombo = max(bestCombo, hud.combo)
        hud.score += GameRules.points(forCombo: hud.combo, brickHitPoints: destroyed ? brick.scoreWeight : 1)
        sound.playBrick(combo: hud.combo, day: level.day)
        impact(at: point, color: brick.baseColor)

        if destroyed {
            hud.bricksRemaining -= 1
            if brick.affinity == .sun {
                hud.sunBricksRemaining -= 1
            } else {
                hud.quietBricksRemaining -= 1
            }
            colorWash.alpha = 0.22 + hud.restoredFraction * 0.70
            maybeDropPowerUp(at: brick.convert(.zero, to: worldNode))
            brick.run(.sequence([
                .group([.scale(to: 1.35, duration: 0.12), .fadeOut(withDuration: 0.16), .rotate(byAngle: .pi / 12, duration: 0.16)]),
                .removeFromParent()
            ]))
        }

        if activeUntil[.piercing] != nil {
            ball.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.paddle | PhysicsCategory.obstacle
        }

        emitHUD()
        if hud.bricksRemaining == 0 {
            finishLevel()
        } else if AffinityRules.shouldTriggerSunshift(
            quietRemaining: hud.quietBricksRemaining,
            sunRemaining: hud.sunBricksRemaining,
            currentMode: hud.ballMode
        ), !sunshiftTransitionQueued {
            sunshiftTransitionQueued = true
            run(.sequence([.wait(forDuration: 0.18), .run { [weak self] in self?.activateSunshift() }]))
        }
    }

    private func bounce(ball: SKNode) {
        guard ball.physicsBody != nil else { return }
        let offset = max(-1, min(1, (ball.position.x - paddle.position.x) / (paddle.frame.width / 2)))
        ball.physicsBody?.velocity = BallPhysics.paddleBounce(offset: offset, speed: desiredBallSpeed)
        hud.combo = max(0, hud.combo - 1)
        sound.playPaddle(offset: Double(offset))
        emitHUD()

        if !settings.reducedMotion {
            paddle.run(.sequence([.scaleY(to: 0.72, duration: 0.035), .scaleY(to: 1, duration: 0.11)]))
        }
    }

    private func lose(ball: SKNode) {
        guard ball.parent != nil, !isFinishing else { return }
        if hasShield {
            hasShield = false
            hud.activePowerUps.removeAll { $0 == .shield }
            ball.position.y = 38
            ball.physicsBody?.velocity = CGVector(dx: ball.physicsBody?.velocity.dx ?? 120, dy: abs(desiredBallSpeed * 0.88))
            shieldFlash()
            emitHUD()
            return
        }

        ball.removeFromParent()
        let remainingBalls = worldNode.childNode(withName: "//ball") != nil
        guard !remainingBalls else { return }

        sound.playMiss()
        hud.lives -= 1
        hud.combo = 0
        clearTimedPowerUps()
        emitHUD()

        if hud.lives <= 0 {
            isFinishing = true
            run(.sequence([.wait(forDuration: 0.55), .run { [weak self] in self?.finishFailure() }]))
        } else {
            run(.sequence([.wait(forDuration: 0.55), .run { [weak self] in self?.spawnWaitingBall() }]))
        }
    }

    private func maybeDropPowerUp(at point: CGPoint) {
        guard Double.random(in: 0...1) < level.powerUpRate else { return }
        let available = PowerUpKind.allCases.filter { $0 != .shield || !hasShield }
        guard let kind = available.randomElement() else { return }
        let node = PowerUpNode(kind: kind, color: NSColor(theme.brickColors[kindIndex(kind) % theme.brickColors.count]))
        node.position = point
        node.zPosition = 15
        worldNode.addChild(node)
        if !settings.reducedMotion {
            node.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 3.2)))
        }
    }

    private func collect(_ powerUp: PowerUpNode) {
        guard powerUp.parent != nil else { return }
        powerUp.removeFromParent()
        sound.playPowerUp(powerUp.kind)

        switch powerUp.kind {
        case .wide:
            paddle.xScale = CGFloat(level.resolvedPaddleScale) * 1.48
            activateTimed(.wide)
        case .multiball:
            spawnAdditionalBalls()
        case .slow:
            activateTimed(.slow)
            desiredBallSpeed = targetBallSpeed
            activeBalls().forEach { ball in
                guard let velocity = ball.physicsBody?.velocity else { return }
                ball.physicsBody?.velocity = BallPhysics.normalizedVelocity(velocity, speed: desiredBallSpeed)
            }
        case .piercing:
            activeBalls().forEach { $0.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.paddle | PhysicsCategory.obstacle }
            activateTimed(.piercing)
        case .shield:
            hasShield = true
            if !hud.activePowerUps.contains(.shield) { hud.activePowerUps.append(.shield) }
        }
        emitHUD()
    }

    private func activateTimed(_ kind: PowerUpKind) {
        guard let duration = GameRules.duration(for: kind) else { return }
        activeUntil[kind] = lastUpdateTime + duration
        if !hud.activePowerUps.contains(kind) { hud.activePowerUps.append(kind) }
    }

    private func expirePowerUps(at time: TimeInterval) {
        let expired = activeUntil.filter { $0.value <= time }.map(\.key)
        guard !expired.isEmpty else { return }
        for kind in expired {
            activeUntil[kind] = nil
            hud.activePowerUps.removeAll { $0 == kind }
            switch kind {
            case .wide:
                paddle.xScale = CGFloat(level.resolvedPaddleScale)
            case .slow:
                break
            case .piercing:
                activeBalls().forEach(updateBallCollisionMask)
            case .multiball, .shield:
                break
            }
        }
        emitHUD()
    }

    private func clearTimedPowerUps() {
        paddle.xScale = CGFloat(level.resolvedPaddleScale)
        activeUntil.removeAll()
        hud.activePowerUps.removeAll { $0 != .shield }
        activeBalls().forEach(updateBallCollisionMask)
    }

    private func spawnAdditionalBalls() {
        guard let source = activeBalls().first else { return }
        let count = min(2, GameRules.maximumBalls - activeBalls().count)
        guard count > 0 else { return }
        for index in 0..<count {
            let ball = makeBall(at: source.position)
            let sign: CGFloat = index == 0 ? -1 : 1
            ball.physicsBody?.velocity = BallPhysics.normalizedVelocity(
                CGVector(dx: 0.55 * sign, dy: 0.84),
                speed: desiredBallSpeed
            )
            worldNode.addChild(ball)
        }
        ballIsWaiting = false
    }

    private func normalizeBallVelocities() {
        guard !ballIsWaiting else { return }
        for ball in activeBalls() {
            guard let velocity = ball.physicsBody?.velocity else { continue }
            ball.physicsBody?.velocity = BallPhysics.normalizedVelocity(velocity, speed: desiredBallSpeed)
            ball.physicsBody?.isResting = false
        }
    }

    private var targetBallSpeed: CGFloat {
        BallPhysics.effectiveSpeed(
            base: baseBallSpeed,
            completion: hud.restoredFraction,
            slowed: activeUntil[.slow] != nil
        )
    }

    private func advanceBallSpeed(deltaTime: TimeInterval) {
        desiredBallSpeed = BallPhysics.approach(
            desiredBallSpeed,
            target: targetBallSpeed,
            deltaTime: deltaTime
        )
    }

    private func activeBalls() -> [SKNode] {
        var balls: [SKNode] = []
        worldNode.enumerateChildNodes(withName: "//ball") { node, _ in balls.append(node) }
        return balls
    }

    private func impact(at point: CGPoint, color: NSColor) {
        let ring = SKShapeNode(circleOfRadius: 8)
        ring.position = point
        ring.strokeColor = color
        ring.fillColor = .clear
        ring.lineWidth = 3
        ring.glowWidth = 5
        ring.zPosition = 25
        worldNode.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 3.2, duration: 0.22), .fadeOut(withDuration: 0.22)]), .removeFromParent()]))

        guard !settings.reducedMotion else { return }
        let strength: CGFloat = min(3.2, 1 + CGFloat(hud.combo) * 0.12)
        let shake = SKAction.sequence([
            .moveBy(x: strength, y: -strength * 0.5, duration: 0.025),
            .moveBy(x: -strength * 2, y: strength, duration: 0.04),
            .moveBy(x: strength, y: -strength * 0.5, duration: 0.035)
        ])
        cameraNode.run(shake)
    }

    private var sunColor: NSColor {
        NSColor(calibratedRed: 1, green: 0.78, blue: 0.08, alpha: 1)
    }

    private func updateBallCollisionMask(_ ball: SKNode) {
        guard activeUntil[.piercing] == nil else {
            ball.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.paddle | PhysicsCategory.obstacle
            return
        }
        let target = sunshiftActive ? PhysicsCategory.sunBrick : PhysicsCategory.brick
        ball.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.paddle | PhysicsCategory.obstacle | target
    }

    private func updateBallAppearance(_ ball: SKNode) {
        guard let shape = ball as? SKShapeNode else { return }
        shape.fillColor = sunshiftActive ? sunColor.withAlphaComponent(0.28) : NSColor(calibratedRed: 0.94, green: 0.96, blue: 1, alpha: 0.14)
        shape.strokeColor = sunshiftActive ? .white : NSColor(theme.neonAccent).withAlphaComponent(0.74)
        shape.glowWidth = sunshiftActive ? 13 : 7
        if let artwork = shape.childNode(withName: "ball-artwork") as? SKSpriteNode {
            artwork.color = sunshiftActive ? sunColor : NSColor(theme.neonAccent)
            artwork.colorBlendFactor = sunshiftActive ? 0.68 : CGFloat(level.resolvedOverlayVariant) * 0.08
        }
        shape.childNode(withName: "ball-trail").map { node in
            (node as? SKEmitterNode)?.particleColor = sunshiftActive ? sunColor : NSColor(theme.brickColors[0])
        }
    }

    private func setPaddleAiming(_ aiming: Bool) {
        paddleSkin.removeAction(forKey: "aiming")
        paddle.childNode(withName: "launch-cradle")?.removeAction(forKey: "aiming")
        if aiming {
            paddleSkin.run(.repeatForever(.sequence([
                .fadeAlpha(to: 1, duration: 0.28),
                .fadeAlpha(to: 0.78, duration: 0.28)
            ])), withKey: "aiming")
            paddle.childNode(withName: "launch-cradle")?.run(.repeatForever(.sequence([
                .scale(to: 1.16, duration: 0.30),
                .scale(to: 0.94, duration: 0.30)
            ])), withKey: "aiming")
        } else {
            paddleSkin.alpha = 0.88
            paddle.childNode(withName: "launch-cradle")?.setScale(1)
        }
    }

    private func activateSunshift() {
        guard !sunshiftActive, hud.sunBricksRemaining > 0, !isFinishing else { return }
        sunshiftActive = true
        sunshiftTransitionQueued = false
        hud.ballMode = .sunshift
        activeBalls().forEach { ball in
            updateBallAppearance(ball)
            updateBallCollisionMask(ball)
        }
        worldNode.enumerateChildNodes(withName: "//brick") { node, _ in
            guard let brick = node as? BrickNode, brick.affinity == .sun else { return }
            brick.run(.group([.fadeAlpha(to: 1, duration: 0.32), .scale(to: 1.05, duration: 0.18)]))
        }
        colorWash.fillColor = sunColor.withAlphaComponent(0.30)
        colorWash.run(.sequence([.fadeAlpha(to: 1, duration: 0.18), .fadeAlpha(to: 0.76, duration: 0.35)]))
        sound.playSunshift()
        sunshiftBanner()
        emitHUD()
    }

    private func sunshiftBanner() {
        let banner = SKLabelNode(text: "☀  SUNSHIFT  ·  YELLOW BALLS BREAK SUN BARS")
        banner.fontName = "AvenirNext-Heavy"
        banner.fontSize = 18
        banner.fontColor = sunColor
        banner.position = CGPoint(x: size.width / 2, y: 650)
        banner.zPosition = 60
        banner.alpha = 0
        worldNode.addChild(banner)
        let arrival = settings.reducedMotion ? SKAction.fadeIn(withDuration: 0.10) : .group([.fadeIn(withDuration: 0.16), .scale(to: 1.06, duration: 0.16)])
        banner.run(.sequence([arrival, .wait(forDuration: 1.15), .fadeOut(withDuration: 0.28), .removeFromParent()]))
    }

    private func resistedImpact(at point: CGPoint, affinity: BrickAffinity) {
        let marker = SKLabelNode(text: affinity == .sun ? "☀" : "◇")
        marker.fontName = "AvenirNext-Heavy"
        marker.fontSize = 15
        marker.fontColor = affinity == .sun ? sunColor : .white.withAlphaComponent(0.55)
        marker.position = point
        marker.zPosition = 30
        worldNode.addChild(marker)
        marker.run(.sequence([.group([.scale(to: 1.6, duration: 0.16), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
    }

    private func shieldFlash() {
        let line = SKShapeNode(rectOf: CGSize(width: 1090, height: 10), cornerRadius: 5)
        line.position = CGPoint(x: size.width / 2, y: 26)
        line.fillColor = NSColor(theme.brickColors[2])
        line.strokeColor = .white
        line.glowWidth = 12
        line.zPosition = 20
        worldNode.addChild(line)
        line.run(.sequence([.fadeOut(withDuration: 0.34), .removeFromParent()]))
    }

    private func finishLevel() {
        guard !isFinishing else { return }
        isFinishing = true
        activeBalls().forEach { $0.physicsBody?.velocity = .zero }
        sound.playComplete()
        celebration()
        let result = LevelResult(
            levelID: level.id,
            score: hud.score + hud.lives * 750,
            stars: GameRules.stars(score: hud.score + hud.lives * 750, totalBricks: hud.totalBricks, completed: true),
            bestCombo: bestCombo,
            didComplete: true
        )
        run(.sequence([.wait(forDuration: settings.reducedMotion ? 0.5 : 1.15), .run { [weak self] in self?.eventHandler(.completed(result)) }]))
    }

    private func finishFailure() {
        let result = LevelResult(levelID: level.id, score: hud.score, stars: 0, bestCombo: bestCombo, didComplete: false)
        eventHandler(.completed(result))
    }

    private func celebration() {
        colorWash.run(.fadeAlpha(to: 1, duration: 0.5))
        guard !settings.reducedMotion else { return }
        for index in 0..<22 {
            let petal = SKShapeNode(circleOfRadius: CGFloat(3 + index % 4))
            petal.fillColor = NSColor(theme.brickColors[index % theme.brickColors.count])
            petal.strokeColor = .clear
            petal.position = CGPoint(x: CGFloat.random(in: 120...1080), y: CGFloat.random(in: 260...690))
            petal.zPosition = 40
            worldNode.addChild(petal)
            let drift = SKAction.moveBy(x: CGFloat.random(in: -80...80), y: -CGFloat.random(in: 150...360), duration: Double.random(in: 0.8...1.4))
            petal.run(.sequence([.group([drift, .rotate(byAngle: .pi * 2, duration: 1), .fadeOut(withDuration: 1.2)]), .removeFromParent()]))
        }
    }

    private func emitHUD() {
        eventHandler(.hud(hud))
    }

    private func kindIndex(_ kind: PowerUpKind) -> Int {
        PowerUpKind.allCases.firstIndex(of: kind) ?? 0
    }
}
