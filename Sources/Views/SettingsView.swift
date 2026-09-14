import SwiftUI

struct SettingsView: View {
    @Bindable var session: GameSession

    var body: some View {
        VStack(spacing: 30) {
            HeaderBar(title: "Settings", subtitle: "Tune the room to your liking") {
                session.saveSettings()
                session.showHome()
            }

            VStack(spacing: 24) {
                SettingSlider(icon: "music.note", title: "Music", value: $session.settings.musicVolume)
                SettingSlider(icon: "speaker.wave.2.fill", title: "Effects", value: $session.settings.effectsVolume)
                Divider().overlay(.white.opacity(0.08))
                SettingToggle(icon: "scope", title: "Aim guide", subtitle: "Show the launch direction", value: $session.settings.aimGuide)
                SettingToggle(icon: "figure.walk.motion", title: "Reduced motion", subtitle: "Remove shake and ambient drift", value: $session.settings.reducedMotion)
            }
            .padding(30)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.11)))
            .frame(maxWidth: 620)

            Text("Progress and settings stay on this Mac. The game never connects to the internet.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.42))
            Spacer()
        }
        .padding(40)
        .onDisappear { session.saveSettings() }
    }
}
private struct SettingSlider: View {
    let icon: String
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(Color(hex: 0xFFE0A8))
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(width: 90, alignment: .leading)
            Slider(value: $value, in: 0...1)
                .tint(Color(hex: 0xF3A68A))
            Text("\(Int(value * 100))%")
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 46)
        }
    }
}

private struct SettingToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var value: Bool

    var body: some View {
        Toggle(isOn: $value) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .frame(width: 28)
                    .foregroundStyle(Color(hex: 0xA7D6C4))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .toggleStyle(.switch)
        .tint(Color(hex: 0xA7D6C4))
    }
}
