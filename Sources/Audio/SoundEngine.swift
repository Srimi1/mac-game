import AVFoundation
import Foundation

@MainActor
final class SoundEngine {
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let sampleRate = 44_100.0
    private var musicVolume: Double
    private var effectsVolume: Double

    init(settings: PlayerSettings) {
        musicVolume = settings.musicVolume
        effectsVolume = settings.effectsVolume
        prepare()
    }

    func stop() {
        players.forEach { $0.stop() }
        engine.stop()
    }

    func playBrick(combo: Int, day: Int) {
        let scale = [0, 2, 4, 7, 9]
        let note = scale[(combo + day) % scale.count]
        playTone(frequency: 220 * pow(2, Double(note) / 12), duration: 0.10, volume: effectsVolume * 0.38, softness: 0.7)
    }

    func playPaddle(offset: Double) {
        playTone(frequency: 150 + abs(offset) * 90, duration: 0.075, volume: effectsVolume * 0.22, softness: 0.3)
    }

    func playPowerUp(_ kind: PowerUpKind) {
        let base: Double = switch kind {
        case .wide: 330
        case .multiball: 392
        case .slow: 262
        case .piercing: 494
        case .shield: 294
        }
        playTone(frequency: base, duration: 0.24, volume: effectsVolume * 0.48, softness: 1)
        playTone(frequency: base * 1.5, duration: 0.18, volume: effectsVolume * 0.30, softness: 1)
    }

    func playMiss() {
        playTone(frequency: 110, duration: 0.28, volume: effectsVolume * 0.32, softness: 1.5)
    }

    func playComplete() {
        [262.0, 330, 392, 523].enumerated().forEach { index, frequency in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(index * 105))
                self?.playTone(frequency: frequency, duration: 0.32, volume: (self?.effectsVolume ?? 0) * 0.5, softness: 1.2)
            }
        }
    }

    func playSunshift() {
        [392.0, 494, 659, 784].enumerated().forEach { index, frequency in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(index * 72))
                self?.playTone(frequency: frequency, duration: 0.28, volume: (self?.effectsVolume ?? 0) * 0.52, softness: 0.9)
            }
        }
    }

    func playAmbient(step: Int, restored: Double, day: Int) {
        guard musicVolume > 0 else { return }
        let scale = [0, 2, 4, 7, 9]
        let note = scale[(step + day * 2) % scale.count]
        let octave = step % 4 == 0 ? 0.5 : 1.0
        playTone(
            frequency: 196 * pow(2, Double(note) / 12) * octave,
            duration: 0.55,
            volume: musicVolume * (0.08 + restored * 0.16),
            softness: 2.8
        )
    }

    private func prepare() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        for _ in 0..<12 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.mainMixerNode.outputVolume = 1
        try? engine.start()
    }

    private func playTone(frequency: Double, duration: Double, volume: Double, softness: Double) {
        guard volume > 0, !players.isEmpty else { return }
        if !engine.isRunning { try? engine.start() }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames

        for frame in 0..<Int(frames) {
            let time = Double(frame) / sampleRate
            let progress = time / duration
            let attack = min(1, progress * 20)
            let decay = pow(max(0, 1 - progress), softness)
            let fundamental = sin(2 * .pi * frequency * time)
            let overtone = sin(2 * .pi * frequency * 2 * time) * 0.16
            channel[frame] = Float((fundamental + overtone) * attack * decay * volume)
        }

        let player = players[nextPlayer % players.count]
        nextPlayer += 1
        if player.isPlaying { player.stop() }
        player.scheduleBuffer(buffer)
        player.play()
    }
}
