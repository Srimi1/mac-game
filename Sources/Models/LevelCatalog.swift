import Foundation
import SwiftUI

enum LevelCatalog {
    static let days: [DayTheme] = [
        DayTheme(id: 1, name: "Morning Room", subtitle: "Let the light back in", icon: "sun.horizon.fill", colors: [Color(hex: 0x050713), Color(hex: 0x35105A)], brickColors: [Color(hex: 0x19E6FF), Color(hex: 0xFF37C7), Color(hex: 0xFF9A62)], backdropAsset: "NeonDay01", neonAccent: Color(hex: 0x19E6FF)),
        DayTheme(id: 2, name: "Rainy Window", subtitle: "Find rhythm in the rain", icon: "cloud.rain.fill", colors: [Color(hex: 0x030815), Color(hex: 0x171E5D)], brickColors: [Color(hex: 0x39DFFF), Color(hex: 0xB75CFF), Color(hex: 0xFF3FBC)], backdropAsset: "NeonDay02", neonAccent: Color(hex: 0x39DFFF)),
        DayTheme(id: 3, name: "Teacup Garden", subtitle: "Wake the sleeping leaves", icon: "leaf.fill", colors: [Color(hex: 0x030914), Color(hex: 0x241052)], brickColors: [Color(hex: 0x00F5D4), Color(hex: 0xFF3CCB), Color(hex: 0x8B7CFF)], backdropAsset: "NeonDay03", neonAccent: Color(hex: 0x00F5D4)),
        DayTheme(id: 4, name: "Kite Sky", subtitle: "Untie the afternoon", icon: "wind", colors: [Color(hex: 0x040716), Color(hex: 0x26105C)], brickColors: [Color(hex: 0x1BE7FF), Color(hex: 0xFF39C6), Color(hex: 0x756CFF)], backdropAsset: "NeonDay04", neonAccent: Color(hex: 0x1BE7FF)),
        DayTheme(id: 5, name: "Lantern Evening", subtitle: "Carry a little glow", icon: "lamp.table.fill", colors: [Color(hex: 0x080511), Color(hex: 0x3D0B50)], brickColors: [Color(hex: 0xFF43C0), Color(hex: 0xFFB13B), Color(hex: 0x20DBFF)], backdropAsset: "NeonDay05", neonAccent: Color(hex: 0xFF43C0)),
        DayTheme(id: 6, name: "Quiet Sunday", subtitle: "Break the old hush", icon: "moon.stars.fill", colors: [Color(hex: 0x02050E), Color(hex: 0x171044)], brickColors: [Color(hex: 0x58E7FF), Color(hex: 0xC050FF), Color(hex: 0xFF4FC3)], backdropAsset: "NeonDay06", neonAccent: Color(hex: 0x58E7FF)),
        DayTheme(id: 7, name: "Prism Workshop", subtitle: "Cut new shapes from light", icon: "hexagon.fill", colors: [Color(hex: 0x050411), Color(hex: 0x28105D)], brickColors: [Color(hex: 0x00F0FF), Color(hex: 0xFF35D3), Color(hex: 0x8C63FF)], backdropAsset: "NeonDay07", neonAccent: Color(hex: 0x00F0FF)),
        DayTheme(id: 8, name: "Golden Hour", subtitle: "Make the whole sky answer", icon: "sun.max.fill", colors: [Color(hex: 0x08040D), Color(hex: 0x4A0D52)], brickColors: [Color(hex: 0xFFD447), Color(hex: 0xFF3EBA), Color(hex: 0x27E6FF)], backdropAsset: "NeonDay08", neonAccent: Color(hex: 0xFFD447))
    ]

    static let levels: [LevelDefinition] = loadLevels()
    static var maximumStars: Int { levels.count * 3 }

    static func theme(for day: Int) -> DayTheme {
        days[max(0, min(days.count - 1, day - 1))]
    }

    static func level(id: String) -> LevelDefinition? {
        levels.first { $0.id == id }
    }

    static func levels(for day: Int) -> [LevelDefinition] {
        levels.filter { $0.day == day }
    }

    private static func loadLevels() -> [LevelDefinition] {
        guard let url = Bundle.main.url(forResource: "levels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([LevelDefinition].self, from: data),
              decoded.count == 24 else {
            assertionFailure("The bundled campaign could not be loaded.")
            return []
        }
        return decoded.sorted { $0.globalIndex < $1.globalIndex }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
