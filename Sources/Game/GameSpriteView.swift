import AppKit
import SpriteKit
import SwiftUI

struct GameSpriteView: NSViewRepresentable {
    let level: LevelDefinition
    let settings: PlayerSettings
    let onEvent: (GameEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent)
    }

    func makeNSView(context: Context) -> GameSKView {
        let view = GameSKView(frame: .zero)
        view.setAccessibilityIdentifier("game-board")
        view.setAccessibilityLabel("Neon game board")
        view.setAccessibilityValue("Ball waiting")
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true
        view.allowsTransparency = true
        view.presentScene(context.coordinator.makeScene(level: level, settings: settings))
        return view
    }

    func updateNSView(_ nsView: GameSKView, context: Context) {
        context.coordinator.onEvent = onEvent
    }

    static func dismantleNSView(_ nsView: GameSKView, coordinator: Coordinator) {
        nsView.presentScene(nil)
    }

    @MainActor
    final class Coordinator {
        var onEvent: (GameEvent) -> Void
        weak var scene: GameScene?

        init(onEvent: @escaping (GameEvent) -> Void) {
            self.onEvent = onEvent
        }

        func makeScene(level: LevelDefinition, settings: PlayerSettings) -> GameScene {
            let scene = GameScene(level: level, settings: settings) { [weak self] event in
                self?.onEvent(event)
            }
            self.scene = scene
            return scene
        }
    }
}

@MainActor
final class GameSKView: SKView {
    private var trackingAreaReference: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        window?.makeFirstResponder(self)
        NotificationCenter.default.removeObserver(self, name: .toggleGamePause, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(togglePauseFromNotification), name: .toggleGamePause, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference { removeTrackingArea(trackingAreaReference) }
        let tracking = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect], owner: self)
        addTrackingArea(tracking)
        trackingAreaReference = tracking
    }

    override func mouseMoved(with event: NSEvent) { updatePaddle(with: event) }
    override func mouseDragged(with event: NSEvent) {
        guard let scene = scene as? GameScene else { return }
        if scene.isBallWaiting {
            scene.updateAim(to: scenePoint(for: event, in: scene))
        } else {
            updatePaddle(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let scene = scene as? GameScene else { return }
        let point = scenePoint(for: event, in: scene)
        if !scene.beginAim(at: point) { scene.movePaddle(to: point.x) }
    }

    override func mouseUp(with event: NSEvent) {
        guard let scene = scene as? GameScene else { return }
        scene.endAimAndLaunch(at: scenePoint(for: event, in: scene))
    }

    override func keyDown(with event: NSEvent) {
        guard let scene = scene as? GameScene else { return }
        switch event.keyCode {
        case 0:
            scene.setKeyboardDirection(-1)
        case 2:
            scene.setKeyboardDirection(1)
        case 123:
            scene.isBallWaiting ? scene.adjustAim(by: -0.065) : scene.setKeyboardDirection(-1)
        case 124:
            scene.isBallWaiting ? scene.adjustAim(by: 0.065) : scene.setKeyboardDirection(1)
        case 49:
            scene.launchBall()
        case 53:
            scene.togglePause()
        #if DEBUG
        case 16:
            scene.testingActivateSunshift()
        #endif
        default:
            super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 0, 2, 123, 124:
            (scene as? GameScene)?.setKeyboardDirection(0)
        default:
            super.keyUp(with: event)
        }
    }

    private func updatePaddle(with event: NSEvent) {
        guard let scene = scene as? GameScene else { return }
        scene.movePaddle(to: scenePoint(for: event, in: scene).x)
    }

    private func scenePoint(for event: NSEvent, in scene: GameScene) -> CGPoint {
        let viewPoint = convert(event.locationInWindow, from: nil)
        return scene.convertPoint(fromView: viewPoint)
    }

    @objc private func togglePauseFromNotification() {
        (scene as? GameScene)?.togglePause()
    }
}
