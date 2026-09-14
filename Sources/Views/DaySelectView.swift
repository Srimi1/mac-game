import SwiftUI

struct DaySelectView: View {
    let session: GameSession
    private let columns = [GridItem(.adaptive(minimum: 275), spacing: 18)]

    var body: some View {
        VStack(spacing: 24) {
            HeaderBar(
                title: "The Quiet Days",
                subtitle: "\(session.progress.totalStars) of \(LevelCatalog.maximumStars) stars gathered · \(LevelCatalog.levels.count) rooms",
                onBack: session.showHome
            )

            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(LevelCatalog.days) { day in
                        DayCard(day: day, session: session)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
        .padding(34)
    }
}

private struct DayCard: View {
    let day: DayTheme
    let session: GameSession

    private var levels: [LevelDefinition] { LevelCatalog.levels(for: day.id) }
    private var unlocked: Bool { levels.first.map(session.isUnlocked) ?? false }
    private var stars: Int { levels.reduce(0) { $0 + (session.progress.stars[$1.id] ?? 0) } }
    private var shapes: [BrickShape] {
        levels.flatMap(\.brickShapes).reduce(into: []) { result, shape in
            if !result.contains(shape) { result.append(shape) }
        }
    }
    private var hasSunshift: Bool { levels.contains(where: \.usesSunshift) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: unlocked ? day.icon : "lock.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(unlocked ? day.brickColors[0] : .white.opacity(0.25))
                Spacer()
                Text("DAY \(day.id)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.45))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(day.name)
                    .font(.system(size: 23, weight: .black, design: .rounded))
                Text(day.subtitle)
                    .foregroundStyle(.white.opacity(0.56))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    MechanicBadge(title: levels.first?.difficultyLabel ?? "GENTLE", icon: "gauge.with.dots.needle.33percent")
                    if hasSunshift {
                        MechanicBadge(title: "SUNSHIFT", icon: "sun.max.fill", tint: Color(hex: 0xFFD447))
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 5) {
                    Text("SHAPES")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.36))
                    ForEach(shapes, id: \.self) { shape in
                        Image(systemName: shape.symbol)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityLabel("Shapes: \(shapes.map(\.title).joined(separator: ", "))")
            }

            HStack(spacing: 9) {
                ForEach(levels) { level in
                    LevelButton(
                        level: level,
                        unlocked: session.isUnlocked(level),
                        stars: session.progress.stars[level.id] ?? 0
                    ) { session.play(level) }
                }
            }

            HStack {
                StarRow(count: min(3, stars / 3))
                Text("\(stars) / 9")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(22)
        .background(
            LinearGradient(colors: day.colors.map { $0.opacity(unlocked ? 0.72 : 0.40) }, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12)))
        .opacity(unlocked ? 1 : 0.82)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct LevelButton: View {
    let level: LevelDefinition
    let unlocked: Bool
    let stars: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text("\(level.stage)")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                if level.usesSunshift {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(Color(hex: 0xFFD447))
                }
                StarRow(count: stars, size: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(unlocked ? .white.opacity(0.09) : .black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityIdentifier("level-\(level.id)")
        .help(unlocked ? "\(level.title) · \(level.difficultyLabel)\(level.usesSunshift ? " · Sunshift" : "")" : "Locked")
        .accessibilityLabel(unlocked ? "Stage \(level.stage), \(level.title)" : "Stage \(level.stage), locked")
    }
}
