import SwiftUI

enum NeonPalette {
    static let void = Color(hex: 0x03040C)
    static let panel = Color(hex: 0x0B0B22)
    static let cyan = Color(hex: 0x19E6FF)
    static let magenta = Color(hex: 0xFF37C7)
    static let violet = Color(hex: 0x8B63FF)
    static let gold = Color(hex: 0xFFD447)
}

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
                    LinearGradient(colors: [NeonPalette.cyan, NeonPalette.magenta, NeonPalette.gold], startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: NeonPalette.magenta.opacity(0.48), radius: compact ? 10 : 22)
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
                .foregroundStyle(enabled ? NeonPalette.void : .white.opacity(0.35))
                .background(
                    Capsule()
                        .fill(enabled ? NeonPalette.cyan : Color.white.opacity(0.08))
                        .shadow(color: enabled ? NeonPalette.cyan.opacity(0.42) : .clear, radius: 16, y: 4)
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
                .background(NeonPalette.panel.opacity(0.84), in: Capsule())
                .overlay(Capsule().stroke(NeonPalette.magenta.opacity(0.38)))
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
                .background(NeonPalette.panel.opacity(0.88), in: Circle())
                .overlay(Circle().stroke(NeonPalette.cyan.opacity(0.42)))
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
                    .foregroundStyle(index < count ? NeonPalette.gold : .white.opacity(0.22))
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
    var tint = NeonPalette.cyan

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
