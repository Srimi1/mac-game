import Foundation
import SwiftUI

enum LevelCatalog {
    static let days: [DayTheme] = [
        DayTheme(id: 1, name: "Morning Room", subtitle: "Let the light back in", icon: "sun.horizon.fill", colors: [Color(hex: 0x30344F), Color(hex: 0xF0B88B)], brickColors: [Color(hex: 0xF6D6A8), Color(hex: 0xECA58B), Color(hex: 0xA7C9B8)]),
        DayTheme(id: 2, name: "Rainy Window", subtitle: "Find rhythm in the rain", icon: "cloud.rain.fill", colors: [Color(hex: 0x273C50), Color(hex: 0x789EB0)], brickColors: [Color(hex: 0xA9D6D2), Color(hex: 0x7DB3C5), Color(hex: 0xD9C2E9)]),
        DayTheme(id: 3, name: "Teacup Garden", subtitle: "Wake the sleeping leaves", icon: "leaf.fill", colors: [Color(hex: 0x33463D), Color(hex: 0xB6C989)], brickColors: [Color(hex: 0xB8D49A), Color(hex: 0xEBCB86), Color(hex: 0xD59B82)]),
        DayTheme(id: 4, name: "Kite Sky", subtitle: "Untie the afternoon", icon: "wind", colors: [Color(hex: 0x354462), Color(hex: 0xA9C8E9)], brickColors: [Color(hex: 0xF4B6A7), Color(hex: 0xF6D589), Color(hex: 0x9FC9D8)]),
        DayTheme(id: 5, name: "Lantern Evening", subtitle: "Carry a little glow", icon: "lamp.table.fill", colors: [Color(hex: 0x26233F), Color(hex: 0xA85F65)], brickColors: [Color(hex: 0xF09A70), Color(hex: 0xE9C46A), Color(hex: 0xC47A93)]),
        DayTheme(id: 6, name: "Quiet Sunday", subtitle: "Break the old hush", icon: "moon.stars.fill", colors: [Color(hex: 0x211F39), Color(hex: 0x7B6D9D)], brickColors: [Color(hex: 0xF2C98A), Color(hex: 0xD694A5), Color(hex: 0x86B9AC)]),
        DayTheme(id: 7, name: "Prism Workshop", subtitle: "Cut new shapes from light", icon: "hexagon.fill", colors: [Color(hex: 0x262451), Color(hex: 0xB44C87)], brickColors: [Color(hex: 0x67E8D2), Color(hex: 0xF06E9C), Color(hex: 0x8EA7FF)]),
        DayTheme(id: 8, name: "Golden Hour", subtitle: "Make the whole sky answer", icon: "sun.max.fill", colors: [Color(hex: 0x44203F), Color(hex: 0xE06F4F)], brickColors: [Color(hex: 0xFFD447), Color(hex: 0xFF7F66), Color(hex: 0x7FE1C5)])
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
