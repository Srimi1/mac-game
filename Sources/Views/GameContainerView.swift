import SwiftUI

struct GameContainerView: View {
    let session: GameSession
    let level: LevelDefinition

    @State private var hud = GameHUDState()
    @State private var paused = false
    @State private var gameID = UUID()
    @State private var showHint = true

    private var theme: DayTheme { LevelCatalog.theme(for: level.day) }

    var body: some View {
        ZStack {
            GameSpriteView(level: level, settings: session.settings, onEvent: handle)
                .id(gameID)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                GameHUDView(level: level, theme: theme, hud: hud) {
                    NotificationCenter.default.post(name: .toggleGamePause, object: nil)
                }
                Spacer()
                if showHint && !paused {
                    Label(hintText, systemImage: level.usesSunshift ? "sun.max.fill" : "cursorarrow.motionlines")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.8)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.38), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.12)))
                        .foregroundStyle(level.usesSunshift ? Color(hex: 0xFFD447) : .white)
                        .transition(.opacity)
                        .padding(.bottom, 22)
                }
            }

            if paused {
                PauseOverlay(
                    onResume: { NotificationCenter.default.post(name: .toggleGamePause, object: nil) },
                    onRestart: restart,
                    onExit: session.showDaySelect
                )
                .transition(.opacity)
            }
        }
        .background(Color(hex: 0x15152A))
        .clipShape(Rectangle())
        .animation(session.settings.reducedMotion ? nil : .easeOut(duration: 0.2), value: paused)
        .task(id: gameID) {
            showHint = true
            try? await Task.sleep(for: .seconds(level.usesSunshift ? 7 : 4))
            withAnimation { showHint = false }
        }
    }

    private var hintText: String {
        if level.usesSunshift {
            return hud.ballMode == .sunshift
                ? "SUNSHIFT ACTIVE  ·  THE YELLOW BALL ONLY BREAKS ☀ BARS"
                : "CLEAR PALE SHAPES  ·  THEN THE BALL TURNS YELLOW FOR ☀ BARS"
        }
        return "MOVE WITH TRACKPAD  ·  CLICK OR SPACE TO LAUNCH"
    }

    private func handle(_ event: GameEvent) {
        switch event {
        case .hud(let nextHUD):
            hud = nextHUD
        case .paused(let isPaused):
            paused = isPaused
        case .completed(let result):
            paused = false
            session.complete(result)
        }
    }

    private func restart() {
        paused = false
        hud = GameHUDState()
        gameID = UUID()
    }
}

private struct GameHUDView: View {
    let level: LevelDefinition
    let theme: DayTheme
    let hud: GameHUDState
    let onPause: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DAY \(level.day) · ROOM \(level.stage)")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.45))
                Text(level.title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.10))
                        Capsule()
                            .fill(LinearGradient(colors: theme.brickColors, startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * hud.restoredFraction)
                    }
                }
                .frame(width: 150, height: 7)
                Text("\(hud.bricksRemaining) shapes remain")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            if hud.sunshiftAvailable {
                PhaseBadge(hud: hud)
            }

            Spacer()

            if !hud.activePowerUps.isEmpty {
                HStack(spacing: 7) {
                    ForEach(hud.activePowerUps, id: \.self) { item in
                        Image(systemName: item.symbol)
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color(hex: 0x24213C))
                            .frame(width: 29, height: 29)
                            .background(Color(hex: 0xA7D6C4), in: Circle())
                            .help(item.title)
                    }
                }
            }

            if hud.combo > 1 {
                Text("×\(hud.combo)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: 0xFFE0A8))
                    .contentTransition(.numericText())
            }

            Text(hud.score.formatted())
                .font(.system(size: 18, weight: .black, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 72, alignment: .trailing)
                .contentTransition(.numericText())

            HStack(spacing: 4) {
                ForEach(0..<GameRules.startingLives, id: \.self) { index in
                    Image(systemName: index < hud.lives ? "heart.fill" : "heart")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(index < hud.lives ? Color(hex: 0xF3A68A) : .white.opacity(0.2))
                }
            }
            .accessibilityLabel("\(hud.lives) lives")

            Button(action: onPause) {
                Image(systemName: "pause.fill")
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.09), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pause")
        }
        .padding(.horizontal, 22)
        .frame(height: 63)
        .background(.black.opacity(0.40))
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }
}

private struct PhaseBadge: View {
    let hud: GameHUDState

    var body: some View {
        let active = hud.ballMode == .sunshift
        HStack(spacing: 7) {
            Image(systemName: active ? "sun.max.fill" : "circle.lefthalf.filled")
            VStack(alignment: .leading, spacing: 0) {
                Text(active ? "SUNSHIFT" : "QUIET PHASE")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1)
                Text(active ? "\(hud.sunBricksRemaining) ☀ bars" : "\(hud.quietBricksRemaining) pale shapes")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .opacity(0.68)
            }
        }
        .foregroundStyle(active ? Color(hex: 0xFFD447) : .white.opacity(0.75))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((active ? Color(hex: 0xFFD447) : .white).opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke((active ? Color(hex: 0xFFD447) : .white).opacity(0.22)))
        .accessibilityLabel(active ? "Sunshift active. \(hud.sunBricksRemaining) sun bars remain." : "Quiet phase. \(hud.quietBricksRemaining) pale shapes remain before Sunshift.")
    }
}

private struct PauseOverlay: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.60)).ignoresSafeArea()
            VStack(spacing: 22) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color(hex: 0xFFE0A8))
                Text("A quiet pause")
                    .font(.system(size: 31, weight: .black, design: .rounded))
                VStack(spacing: 10) {
                    PrimaryButton(title: "Keep Playing", icon: "play.fill", action: onResume)
                    GlassButton(title: "Restart Room", icon: "arrow.counterclockwise", action: onRestart)
                    GlassButton(title: "Leave for Day Select", icon: "rectangle.portrait.and.arrow.right", action: onExit)
                }
                .frame(width: 330)
            }
            .padding(38)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.14)))
        }
    }
}
