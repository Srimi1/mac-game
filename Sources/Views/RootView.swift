import SwiftUI

struct RootView: View {
    let session: GameSession

    var body: some View {
        ZStack {
            DreamBackground(reducedMotion: session.settings.reducedMotion)
                .ignoresSafeArea()

            Group {
                switch session.route {
                case .home:
                    HomeView(session: session)
                case .daySelect:
                    DaySelectView(session: session)
                case .game:
                    if let level = session.selectedLevel {
                        GameContainerView(session: session, level: level)
                            .id(level.id)
                    } else {
                        HomeView(session: session)
                    }
                case .results:
                    ResultsView(session: session)
                case .settings:
                    SettingsView(session: session)
                case .credits:
                    CreditsView(session: session)
                case .finale:
                    FinaleView(session: session)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
        .preferredColorScheme(.dark)
        .animation(session.settings.reducedMotion ? nil : .easeInOut(duration: 0.38), value: session.route)
    }
}
struct DreamBackground: View {
    let reducedMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1 / 30)) { timeline in
            Canvas { context, size in
                let time = reducedMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let bounds = CGRect(origin: .zero, size: size)
                context.fill(
                    Path(bounds),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0x15152A), Color(hex: 0x2A2848), Color(hex: 0x3B3150)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )

                for index in 0..<12 {
                    let phase = Double(index) * 0.73
                    let x = (sin(time * 0.06 + phase) * 0.12 + Double(index % 4) / 3.0) * size.width
                    let y = (cos(time * 0.05 + phase) * 0.10 + Double(index / 4) / 2.0) * size.height
                    let radius = 70 + CGFloat(index % 3) * 35
                    let circle = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    context.fill(circle, with: .color([Color.orange, Color.mint, Color.pink][index % 3].opacity(0.035)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
