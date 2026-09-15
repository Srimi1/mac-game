import SwiftUI

struct HomeView: View {
    let session: GameSession
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 34) {
            VStack(alignment: .leading, spacing: 28) {
                QuietTitle()
                    .fixedSize(horizontal: true, vertical: false)

                Text("A tiny ball. Twenty-four electric rooms.\nAim your shot, split the neon, and wake the night.")
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineSpacing(6)

                VStack(spacing: 11) {
                    PrimaryButton(
                        title: session.progress.bestScores.isEmpty ? "Begin the First Day" : "Continue the Day",
                        icon: "play.fill",
                        enabled: session.continueLevel != nil
                    ) {
                        if let level = session.continueLevel { session.play(level) }
                    }
                    GlassButton(title: "Choose a Day", icon: "square.grid.2x2.fill") { session.showDaySelect() }

                    HStack(spacing: 10) {
                        GlassButton(title: "Settings", icon: "slider.horizontal.3") { session.showSettings() }
                        GlassButton(title: "Credits", icon: "heart.fill") { session.showCredits() }
                    }
                }
                .frame(maxWidth: 390)
            }
            .frame(maxWidth: 445, alignment: .leading)
            .layoutPriority(1)

            HomeOrbitalArt(reducedMotion: session.settings.reducedMotion)
                .frame(width: 340, height: 390)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
        }
        .frame(maxWidth: 1_050)
        .padding(.horizontal, 38)
        .padding(.vertical, 42)
        .onAppear {
            guard !session.settings.reducedMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.78)) { appeared = true }
        }
    }
}

private struct HomeOrbitalArt: View {
    let reducedMotion: Bool
    private let brickAssets = [
        "NeonBrickRounded", "NeonBrickCapsule", "NeonBrickDiamond",
        "NeonBrickTriangle", "NeonBrickHexagon"
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1 / 30)) { timeline in
            let time = reducedMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                let ballCenter = CGPoint(
                    x: size.width * 0.72 + cos(time * 0.9) * 5,
                    y: size.height * 0.46 + sin(time * 0.9) * 5
                )
                ZStack {
                    Circle()
                        .fill(NeonPalette.magenta.opacity(0.18))
                        .blur(radius: 34)
                        .frame(width: 260, height: 260)
                        .position(x: size.width * 0.53, y: size.height * 0.52)

                    ForEach(0..<20, id: \.self) { index in
                        let row = index / 5
                        let column = index % 5
                        let float = CGFloat(sin(time * 0.8 + Double(index)) * 2.4)
                        Image(brickAssets[(row * 2 + column) % brickAssets.count])
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 31)
                            .shadow(color: [NeonPalette.cyan, NeonPalette.magenta, NeonPalette.violet][index % 3].opacity(0.32), radius: 5)
                            .position(
                                x: size.width * 0.16 + CGFloat(column) * size.width * 0.16,
                                y: size.height * 0.16 + CGFloat(row) * size.height * 0.11 + float
                            )
                    }

                    Canvas { context, _ in
                        var trail = Path()
                        trail.move(to: CGPoint(x: size.width * 0.27, y: size.height * 0.84))
                        trail.addQuadCurve(to: ballCenter, control: CGPoint(x: size.width * 0.18, y: size.height * 0.58))
                        context.stroke(
                            trail,
                            with: .linearGradient(
                                Gradient(colors: [.clear, NeonPalette.cyan]),
                                startPoint: CGPoint(x: size.width * 0.27, y: size.height * 0.84),
                                endPoint: ballCenter
                            ),
                            lineWidth: 4
                        )
                    }

                    Image("NeonBall")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .rotationEffect(.radians(time * 1.8))
                        .shadow(color: NeonPalette.cyan.opacity(0.75), radius: 9)
                        .position(ballCenter)

                    Image("NeonPaddle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 168, height: 34)
                        .shadow(color: NeonPalette.magenta.opacity(0.48), radius: 8)
                        .position(x: size.width * 0.42, y: size.height * 0.87)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
