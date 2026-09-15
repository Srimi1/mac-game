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
        ZStack {
            Image("NeonMenu")
                .resizable()
                .scaledToFill()
                .overlay(Color(hex: 0x02040D).opacity(0.34))

            TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1 / 30)) { timeline in
                Canvas { context, size in
                    let time = reducedMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    let bounds = CGRect(origin: .zero, size: size)
                    context.fill(Path(bounds), with: .linearGradient(
                        Gradient(colors: [.clear, Color(hex: 0x0A0520).opacity(0.62)]),
                        startPoint: CGPoint(x: size.width / 2, y: 0),
                        endPoint: CGPoint(x: size.width / 2, y: size.height)
                    ))

                    for index in 0..<10 {
                        let phase = Double(index) * 0.81
                        let x = (sin(time * 0.10 + phase) * 0.08 + Double(index % 5) / 4.0) * size.width
                        let y = (cos(time * 0.08 + phase) * 0.06 + Double(index / 5) * 0.75) * size.height
                        let radius: CGFloat = 2 + CGFloat(index % 3)
                        let circle = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                        context.fill(circle, with: .color([NeonPalette.cyan, NeonPalette.magenta][index % 2].opacity(0.55)))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
