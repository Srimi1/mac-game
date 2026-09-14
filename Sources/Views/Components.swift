import SwiftUI

struct QuietTitle: View {
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 3 : 8) {
            Text("BREAK THE")
                .font(.system(size: compact ? 13 : 17, weight: .bold, design: .rounded))
                .tracking(compact ? 4 : 7)
                .foregroundStyle(.white.opacity(0.65))
            Text("QUIET DAYS")
                .font(.system(size: compact ? 30 : 58, weight: .black, design: .rounded))
                .tracking(compact ? 0.5 : 1.5)
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex: 0xFFE0A8), Color(hex: 0xF3A68A), Color(hex: 0xA7D6C4)], startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: Color(hex: 0xF3A68A).opacity(0.35), radius: compact ? 10 : 22)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Break the Quiet Days")
    }
}

struct PrimaryButton: View {
    let title: String
    let icon: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(enabled ? Color(hex: 0x24213C) : .white.opacity(0.35))
                .background(
                    Capsule()
                        .fill(enabled ? Color(hex: 0xFFE0A8) : Color.white.opacity(0.08))
                        .shadow(color: enabled ? Color(hex: 0xF3A68A).opacity(0.28) : .clear, radius: 14, y: 5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct GlassButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(.white.opacity(0.07), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .bold))
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

struct StarRow: View {
    let count: Int
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < count ? "star.fill" : "star")
                    .foregroundStyle(index < count ? Color(hex: 0xFFE0A8) : .white.opacity(0.22))
                    .font(.system(size: size, weight: .bold))
            }
        }
        .accessibilityLabel("\(count) of 3 stars")
    }
}

struct HeaderBar: View {
    let title: String
    let subtitle: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            BackButton(action: onBack)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                Text(subtitle)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
        }
    }
}

struct MechanicBadge: View {
    let title: String
    let icon: String
    var tint = Color(hex: 0xFFE0A8)

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .tracking(0.8)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(tint.opacity(0.11), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.24)))
    }
}
