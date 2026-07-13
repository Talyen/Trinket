import SwiftUI
import TrinketCore

public extension Keyword {
    struct VisualStyle: Sendable {
        public let color: Color
        public let secondaryColor: Color
        public let glowColor: Color
        public let subtleBackgroundColor: Color
        public let borderColor: Color
        public let symbolName: String
        public let prefersDarkForeground: Bool

        public init(color: Color, secondaryColor: Color? = nil, symbolName: String, prefersDarkForeground: Bool = false) {
            self.color = color
            self.secondaryColor = secondaryColor ?? color.opacity(0.72)
            glowColor = color.opacity(0.62)
            subtleBackgroundColor = color.opacity(0.14)
            borderColor = color.opacity(0.48)
            self.symbolName = symbolName
            self.prefersDarkForeground = prefersDarkForeground
        }

        public static let physical = VisualStyle(
            color: DesignAssetColors.named("KeywordPhysical"),
            symbolName: "burst.fill"
        )
        public static let burn = VisualStyle(
            color: DesignAssetColors.named("KeywordBurn"),
            secondaryColor: DesignAssetColors.named("KeywordPhysical"),
            symbolName: "flame.fill"
        )
        public static let stun = VisualStyle(
            color: DesignAssetColors.named("KeywordStun"),
            symbolName: "bolt.fill",
            prefersDarkForeground: true
        )
        public static let block = VisualStyle(
            color: DesignAssetColors.named("KeywordBlock"),
            symbolName: "shield.fill"
        )
        public static let armor = VisualStyle(
            color: DesignAssetColors.named("KeywordArmor"),
            symbolName: "shield.lefthalf.filled"
        )
        public static let health = VisualStyle(
            color: DesignAssetColors.named("KeywordHealth"),
            secondaryColor: ThemePalette.trinket.health,
            symbolName: "heart.fill"
        )
        public static let gold = VisualStyle(
            color: DesignAssetColors.named("KeywordGold"),
            symbolName: "circle.circle.fill",
            prefersDarkForeground: true
        )
        public static let holy = VisualStyle(
            color: DesignAssetColors.named("KeywordHoly"),
            symbolName: "sun.max.fill",
            prefersDarkForeground: true
        )
        public static let poison = VisualStyle(
            color: DesignAssetColors.named("KeywordPoison"),
            symbolName: "drop.fill"
        )
        public static let bleed = VisualStyle(
            color: DesignAssetColors.named("KeywordBleed"),
            symbolName: "drop.fill"
        )
        public static let leech = VisualStyle(
            color: DesignAssetColors.named("KeywordLeech"),
            symbolName: "drop"
        )
        public static let nature = VisualStyle(
            color: DesignAssetColors.named("KeywordNature"),
            symbolName: "leaf.fill"
        )
        public static let freeze = VisualStyle(
            color: DesignAssetColors.named("KeywordFreeze"),
            symbolName: "snowflake",
            prefersDarkForeground: true
        )
        public static let dodge = VisualStyle(
            color: DesignAssetColors.named("KeywordDodge"),
            symbolName: "figure.run"
        )
        public static let purge = VisualStyle(
            color: DesignAssetColors.named("KeywordPurge"),
            symbolName: "sparkles"
        )
        public static let mana = VisualStyle(
            color: DesignAssetColors.named("KeywordMana"),
            symbolName: "moon.stars.fill"
        )
        public static let deathsDoor = VisualStyle(
            color: DesignAssetColors.named("KeywordDeathsDoor"),
            symbolName: "heart.slash.fill"
        )
    }

    var visualStyle: VisualStyle {
        switch self {
        case .physical: .physical
        case .burn: .burn
        case .stun: .stun
        case .block: .block
        case .armor: .armor
        case .health: .health
        case .gold: .gold
        case .holy: .holy
        case .poison: .poison
        case .bleed: .bleed
        case .leech: .leech
        case .nature: .nature
        case .freeze: .freeze
        case .dodge: .dodge
        case .purge: .purge
        case .mana: .mana
        case .deathsDoor: .deathsDoor
        }
    }
}
