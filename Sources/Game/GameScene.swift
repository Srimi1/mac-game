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
    private let colorWash = SKShapeNode(rectOf: CGSize(width: 1400, height: 900))
    private let aimGuide = SKShapeNode()
    private let cameraNode = SKCameraNode()
    private var hud = GameHUDState()
    private var keyboardDirection: CGFloat = 0
    private var ballIsWaiting = true
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
    var testingPaddleX: CGFloat { paddle.position.x }
    var testingBallVelocity: CGVector? { activeBalls().first?.physicsBody?.velocity }
    var testingBallCollisionMask: UInt32? { activeBalls().first?.physicsBody?.collisionBitMask }
    var testingBallFillColor: NSColor? { (activeBalls().first as? SKShapeNode)?.fillColor }
    var testingSunBrickCount: Int { hud.sunBricksRemaining }
    var testingQuietBrickCount: Int { hud.quietBricksRemaining }
    var testingBallMode: BallMode { hud.ballMode }
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
        aimGuide.isHidden = true
        ball.physicsBody?.velocity = CGVector(dx: desiredBallSpeed * 0.42, dy: desiredBallSpeed * 0.91)
        sound.playPaddle(offset: 0)
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
            if gamepad.buttonA.isPressed, ballIsWaiting { launchBall() }
            let menuPressed = gamepad.buttonMenu.isPressed
            if menuPressed && !controllerMenuWasPressed { togglePause() }
            controllerMenuWasPressed = menuPressed
        }

        expirePowerUps(at: currentTime)
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
        }
    }

    private func buildBackground() {
        colorWash.fillColor = NSColor(theme.colors[1]).withAlphaComponent(0.20)
        colorWash.strokeColor = .clear
        colorWash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        colorWash.zPosition = -90
        worldNode.addChild(colorWash)

        for index in 0..<11 {
            let radius = CGFloat(22 + (index % 4) * 16)
            let mote = SKShapeNode(circleOfRadius: radius)
            mote.fillColor = NSColor(theme.brickColors[index % theme.brickColors.count]).withAlphaComponent(0.055)
            mote.strokeColor = .clear
            mote.position = CGPoint(x: 70 + CGFloat((index * 127) % 1080), y: 90 + CGFloat((index * 83) % 590))
            mote.zPosition = -80
            worldNode.addChild(mote)
            if !settings.reducedMotion {
                let drift = SKAction.moveBy(x: CGFloat((index % 3) - 1) * 26, y: CGFloat(index % 2 == 0 ? 18 : -18), duration: 4.5 + Double(index % 3))
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
        paddle.fillColor = NSColor(calibratedRed: 0.96, green: 0.90, blue: 0.82, alpha: 1)
        paddle.strokeColor = NSColor(theme.brickColors[1])
        paddle.lineWidth = 3
        paddle.glowWidth = 5
        paddle.position = CGPoint(x: size.width / 2, y: 74)
        paddle.xScale = CGFloat(level.resolvedPaddleScale)
        paddle.zPosition = 10
        paddle.name = "paddle"
        paddle.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 174, height: 22))
        paddle.physicsBody?.isDynamic = false
        paddle.physicsBody?.categoryBitMask = PhysicsCategory.paddle
        paddle.physicsBody?.collisionBitMask = PhysicsCategory.ball
        paddle.physicsBody?.contactTestBitMask = PhysicsCategory.ball | PhysicsCategory.powerUp
        paddle.physicsBody?.friction = 0
        paddle.physicsBody?.restitution = 1
        worldNode.addChild(paddle)
    }

    private func buildBricks() {
        let availableWidth: CGFloat = 1050
        let gap: CGFloat = 9
        let brickWidth = (availableWidth - CGFloat(level.columns - 1) * gap) / CGFloat(level.columns)
        let brickHeight: CGFloat = max(28, min(38, 255 / CGFloat(level.rows)))
        let startX = (size.width - availableWidth) / 2 + brickWidth / 2
        let startY: CGFloat = 625
        var placed = 0
        var quietPlaced = 0
        var sunPlaced = 0

        for row in 0..<level.rows {
            let rowNode = SKNode()
            rowNode.name = "brick-row-\(row)"
            rowNode.zPosition = 2
            worldNode.addChild(rowNode)

            for column in 0..<level.columns where BrickPattern.contains(level.pattern, row: row, column: column, rows: level.rows, columns: level.columns) {
                let durable = level.durableEvery > 0 && placed % level.durableEvery == 0
                let extraTough = level.resolvedTripleEvery > 0 && placed % level.resolvedTripleEvery == 0
                let hits = extraTough ? 3 : (durable ? 2 : 1)
                let color = NSColor(theme.brickColors[(row + column) % theme.brickColors.count])
                let affinity: BrickAffinity = AffinityRules.shouldBeSunBrick(
                    index: placed,
                    row: row,
                    column: column,
                    rate: level.sunBrickRate
                ) ? .sun : .quiet
                let shapes = level.brickShapes
                let shape = shapes[(row * 3 + column + placed) % shapes.count]
                let brick = BrickNode(
                    size: CGSize(width: brickWidth, height: brickHeight),
                    color: color,
                    hitPoints: hits,
                    shape: shape,
                    affinity: affinity
                )
                brick.position = CGPoint(x: startX + CGFloat(column) * (brickWidth + gap), y: startY - CGFloat(row) * (brickHeight + gap))
                brick.alpha = affinity == .sun ? 0.40 : 0.84
                rowNode.addChild(brick)
                if affinity == .sun { sunPlaced += 1 } else { quietPlaced += 1 }
                placed += 1
            }

            if level.movingRows.contains(row), !settings.reducedMotion {
                let distance: CGFloat = row % 2 == 0 ? 24 : -24
                let move = SKAction.moveBy(x: distance, y: 0, duration: 1.8 + Double(row % 3) * 0.35)
                move.timingMode = .easeInEaseOut
                rowNode.run(.repeatForever(.sequence([move, move.reversed()])))
            }
        }

        hud.totalBricks = placed
        hud.bricksRemaining = placed
        hud.quietBricksRemaining = quietPlaced
        hud.sunBricksRemaining = sunPlaced
        hud.sunshiftAvailable = sunPlaced > 0
        hud.ballMode = .quiet
    }

    private func buildAimGuide() {
        aimGuide.strokeColor = .white.withAlphaComponent(0.26)
        aimGuide.lineWidth = 2
        aimGuide.glowWidth = 2
        aimGuide.zPosition = 1
        aimGuide.isHidden = !settings.aimGuide
        worldNode.addChild(aimGuide)
        updateAimGuide()
    }

    private func updateAimGuide() {
        guard settings.aimGuide, ballIsWaiting else { return }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: paddle.position.x, y: 104))
        path.addLine(to: CGPoint(x: paddle.position.x + 84, y: 285))
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
        updateAimGuide()
    }

    private func makeBall(at point: CGPoint) -> SKShapeNode {
        let ball = SKShapeNode(circleOfRadius: 11)
        ball.name = "ball"
        ball.lineWidth = 2
        ball.position = point
        ball.zPosition = 20
        ball.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        ball.physicsBody?.isDynamic = true
        ball.physicsBody?.affectedByGravity = false
        ball.physicsBody?.allowsRotation = false
        ball.physicsBody?.linearDamping = 0
        ball.physicsBody?.friction = 0
        ball.physicsBody?.restitution = 1
        ball.physicsBody?.usesPreciseCollisionDetection = true
        ball.physicsBody?.categoryBitMask = PhysicsCategory.ball
        ball.physicsBody?.contactTestBitMask = PhysicsCategory.paddle | PhysicsCategory.brick | PhysicsCategory.sunBrick | PhysicsCategory.bottom
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
        let destroyed = brick.takeHit()
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
            ball.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.paddle
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
        guard var velocity = ball.physicsBody?.velocity else { return }
        let offset = max(-1, min(1, (ball.position.x - paddle.position.x) / (paddle.frame.width / 2)))
        let angle = offset * (.pi * 0.34)
        velocity.dx = desiredBallSpeed * sin(angle)
        velocity.dy = abs(desiredBallSpeed * cos(angle))
        ball.physicsBody?.velocity = velocity
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
            paddle.xScale = 1.48
            activateTimed(.wide)
        case .multiball:
            spawnAdditionalBalls()
        case .slow:
            desiredBallSpeed = baseBallSpeed * 0.72
            activeBalls().forEach { ball in
                guard let velocity = ball.physicsBody?.velocity else { return }
                ball.physicsBody?.velocity = scaled(velocity, to: desiredBallSpeed)
            }
            activateTimed(.slow)
        case .piercing:
            activeBalls().forEach { $0.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.paddle }
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
                paddle.xScale = 1
            case .slow:
                desiredBallSpeed = baseBallSpeed
            case .piercing:
                activeBalls().forEach(updateBallCollisionMask)
            case .multiball, .shield:
                break
            }
        }
        emitHUD()
    }

    private func clearTimedPowerUps() {
        paddle.xScale = 1
        desiredBallSpeed = baseBallSpeed
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
            ball.physicsBody?.velocity = CGVector(dx: desiredBallSpeed * 0.55 * sign, dy: desiredBallSpeed * 0.84)
            worldNode.addChild(ball)
        }
        ballIsWaiting = false
    }

    private func normalizeBallVelocities() {
        guard !ballIsWaiting else { return }
        for ball in activeBalls() {
            guard var velocity = ball.physicsBody?.velocity else { continue }
            velocity = scaled(velocity, to: desiredBallSpeed)
            let minimumVertical = desiredBallSpeed * 0.24
            if abs(velocity.dy) < minimumVertical {
                velocity.dy = velocity.dy >= 0 ? minimumVertical : -minimumVertical
                velocity = scaled(velocity, to: desiredBallSpeed)
            }
            ball.physicsBody?.velocity = velocity
        }
    }

    private func activeBalls() -> [SKNode] {
        var balls: [SKNode] = []
        worldNode.enumerateChildNodes(withName: "//ball") { node, _ in balls.append(node) }
        return balls
    }

    private func scaled(_ vector: CGVector, to magnitude: CGFloat) -> CGVector {
        let current = max(0.001, hypot(vector.dx, vector.dy))
        return CGVector(dx: vector.dx / current * magnitude, dy: vector.dy / current * magnitude)
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
            ball.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.paddle
            return
        }
        let target = sunshiftActive ? PhysicsCategory.sunBrick : PhysicsCategory.brick
        ball.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.paddle | target
    }

    private func updateBallAppearance(_ ball: SKNode) {
        guard let shape = ball as? SKShapeNode else { return }
        shape.fillColor = sunshiftActive ? sunColor : NSColor(calibratedRed: 0.94, green: 0.96, blue: 1, alpha: 1)
        shape.strokeColor = sunshiftActive ? .white : NSColor(theme.brickColors[0])
        shape.glowWidth = sunshiftActive ? 16 : 9
        shape.childNode(withName: "ball-trail").map { node in
            (node as? SKEmitterNode)?.particleColor = sunshiftActive ? sunColor : NSColor(theme.brickColors[0])
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
