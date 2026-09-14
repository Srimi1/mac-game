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
    override func mouseDragged(with event: NSEvent) { updatePaddle(with: event) }

    override func mouseDown(with event: NSEvent) {
        updatePaddle(with: event)
        (scene as? GameScene)?.launchBall()
    }

    override func keyDown(with event: NSEvent) {
        guard let scene = scene as? GameScene else { return }
        switch event.keyCode {
        case 0, 123:
            scene.setKeyboardDirection(-1)
        case 2, 124:
            scene.setKeyboardDirection(1)
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
        let viewPoint = convert(event.locationInWindow, from: nil)
        let scenePoint = scene.convertPoint(fromView: viewPoint)
        scene.movePaddle(to: scenePoint.x)
    }

    @objc private func togglePauseFromNotification() {
        (scene as? GameScene)?.togglePause()
    }
}
