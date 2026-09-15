import SwiftUI

struct ResultsView: View {
    let session: GameSession

    var body: some View {
        VStack(spacing: 27) {
            if let result = session.lastResult, let level = session.selectedLevel {
                Image(systemName: result.didComplete ? "sparkles" : "moon.zzz.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(result.didComplete ? NeonPalette.cyan : .white.opacity(0.45))
                Text(result.didComplete ? "The room is singing" : "The room went quiet")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                Text("Day \(level.day) · \(level.title)")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.55))
                StarRow(count: result.stars, size: 28)

                HStack(spacing: 42) {
                    ResultStat(label: "SCORE", value: result.score.formatted())
                    ResultStat(label: "BEST COMBO", value: "×\(result.bestCombo)")
                }

                VStack(spacing: 11) {
                    if result.didComplete {
                        PrimaryButton(title: "Next Room", icon: "arrow.right") { session.playNext() }
                    }
                    GlassButton(title: "Play Again", icon: "arrow.counterclockwise") { session.retry() }
                    GlassButton(title: "Day Select", icon: "square.grid.2x2.fill") { session.showDaySelect() }
                }
                .frame(width: 360)
            }
        }
        .padding(48)
    }
}

private struct ResultStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(label).font(.caption2.bold()).tracking(2).foregroundStyle(.white.opacity(0.42))
            Text(value).font(.system(size: 26, weight: .black, design: .rounded)).monospacedDigit()
        }
    }
}

struct FinaleView: View {
    let session: GameSession
    @State private var glow = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sun.max.trianglebadge.exclamationmark.fill")
                .font(.system(size: 68))
                .foregroundStyle(NeonPalette.gold)
                .shadow(color: NeonPalette.magenta.opacity(glow ? 0.8 : 0.2), radius: glow ? 38 : 12)
                .scaleEffect(glow ? 1.04 : 0.98)
            Text("Tomorrow won’t be quiet.")
                .font(.system(size: 42, weight: .black, design: .rounded))
            Text("You broke the hush, one bright note at a time.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.62))
            Text("\(session.progress.totalStars) of \(LevelCatalog.maximumStars) stars")
                .font(.headline)
                .foregroundStyle(NeonPalette.cyan)
            HStack(spacing: 12) {
                GlassButton(title: "Visit the Days", icon: "square.grid.2x2.fill") { session.showDaySelect() }
                GlassButton(title: "Home", icon: "house.fill") { session.showHome() }
            }
            .frame(width: 480)
        }
        .onAppear {
            guard !session.settings.reducedMotion else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

struct CreditsView: View {
    let session: GameSession

    var body: some View {
        VStack(spacing: 30) {
            HeaderBar(title: "Made for a Quiet Mac", subtitle: "A small original game", onBack: session.showHome)
            Spacer()
            QuietTitle(compact: true)
            Text("Design, code, generative sound, and original artwork\ncreated for this MacBook Air.")
                .multilineTextAlignment(.center)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.62))
                .lineSpacing(5)
            Text("Built with SwiftUI, SpriteKit, GameController, and AVFoundation.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.38))
            Spacer()
            Text("No ads · No tracking · No network")
                .font(.caption.bold())
                .tracking(1.5)
                .foregroundStyle(NeonPalette.cyan.opacity(0.8))
        }
        .padding(40)
    }
}
