import SwiftUI

@main
struct BreakTheQuietDaysApp: App {
    @State private var session = GameSession()

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
                .frame(minWidth: 960, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Game") {
                Button("Day Select") { session.showDaySelect() }
                    .keyboardShortcut("d", modifiers: [.command])
                Button("Pause / Resume") {
                    NotificationCenter.default.post(name: .toggleGamePause, object: nil)
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(session.route != .game)
            }
        }
    }
}
extension Notification.Name {
    static let toggleGamePause = Notification.Name("BreakTheQuietDays.toggleGamePause")
}
