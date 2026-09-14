import SwiftUI

struct HomeView: View {
    let session: GameSession
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 56) {
            VStack(alignment: .leading, spacing: 28) {
                QuietTitle()

                Text("A tiny ball. Twenty-four sleeping rooms.\nNew shapes, tougher walls, and a sunlit second phase.")
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
            .frame(maxWidth: 520, alignment: .leading)

            HomeOrbitalArt(reducedMotion: session.settings.reducedMotion)
                .frame(width: 390, height: 430)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
        }
        .padding(60)
        .onAppear {
            guard !session.settings.reducedMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.78)) { appeared = true }
        }
    }
}

private struct HomeOrbitalArt: View {
    let reducedMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1 / 30)) { timeline in
            let time = reducedMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2 + 15)
                let glow = Path(ellipseIn: CGRect(x: center.x - 150, y: center.y - 150, width: 300, height: 300))
                context.fill(glow, with: .radialGradient(Gradient(colors: [Color(hex: 0xF3A68A).opacity(0.22), .clear]), center: center, startRadius: 0, endRadius: 150))

                for row in 0..<4 {
                    for column in 0..<5 {
                        let offset = CGFloat(sin(time * 0.8 + Double(row * 5 + column)) * 3)
                        let rect = CGRect(x: 64 + CGFloat(column) * 56, y: 55 + CGFloat(row) * 43 + offset, width: 45, height: 29)
                        let path: Path = switch (row + column) % 4 {
                        case 1: Path(ellipseIn: rect)
                        case 2: Path { path in
                            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
                            path.closeSubpath()
                        }
                        case 3: Path { path in
                            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                            path.closeSubpath()
                        }
                        default: Path(roundedRect: rect, cornerRadius: 9)
                        }
                        let palette = [Color(hex: 0xF6D6A8), Color(hex: 0xECA58B), Color(hex: 0xA7C9B8)]
                        context.fill(path, with: .color(palette[(row + column) % palette.count].opacity(0.88)))
                    }
                }

                var trail = Path()
                trail.move(to: CGPoint(x: 95, y: 340))
                trail.addQuadCurve(to: CGPoint(x: 275, y: 185), control: CGPoint(x: 80, y: 220))
                context.stroke(trail, with: .linearGradient(Gradient(colors: [.clear, Color(hex: 0xFFE0A8)]), startPoint: CGPoint(x: 95, y: 340), endPoint: CGPoint(x: 275, y: 185)), lineWidth: 5)

                let orbit = time * 0.9
                let ballCenter = CGPoint(x: 275 + cos(orbit) * 5, y: 185 + sin(orbit) * 5)
                context.fill(Path(ellipseIn: CGRect(x: ballCenter.x - 14, y: ballCenter.y - 14, width: 28, height: 28)), with: .radialGradient(Gradient(colors: [.white, Color(hex: 0xFFE0A8)]), center: ballCenter, startRadius: 1, endRadius: 16))

                let paddle = Path(roundedRect: CGRect(x: 89, y: 342, width: 155, height: 27), cornerRadius: 14)
                context.fill(paddle, with: .color(Color(hex: 0xF6E7D3)))
                context.stroke(paddle, with: .color(Color(hex: 0xF3A68A)), lineWidth: 2)
            }
        }
        .accessibilityHidden(true)
    }
}
