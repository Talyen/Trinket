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

        public static let physical = VisualStyle(color: Color.orange, symbolName: "bolt.fill")
        public static let burn = VisualStyle(color: Color.red, secondaryColor: Color.orange, symbolName: "flame.fill")
        public static let stun = VisualStyle(color: Color.yellow, symbolName: "bolt.fill", prefersDarkForeground: true)
        public static let block = VisualStyle(color: Color.blue, symbolName: "shield.fill")
        public static let armor = VisualStyle(color: Color.gray, symbolName: "shield.lefthalf.filled")
        public static let health = VisualStyle(color: Color.red, secondaryColor: Color.green, symbolName: "heart.fill")
        public static let gold = VisualStyle(color: DesignAssetColors.named("KeywordGold"), symbolName: "dollarsign.circle.fill", prefersDarkForeground: true)
        public static let holy = VisualStyle(color: DesignAssetColors.named("KeywordHoly"), symbolName: "sun.max.fill", prefersDarkForeground: true)
        public static let poison = VisualStyle(color: DesignAssetColors.named("KeywordPoison"), symbolName: "drop.triangle.fill")
        public static let bleed = VisualStyle(color: DesignAssetColors.named("KeywordBleed"), symbolName: "drop.fill")
        public static let leech = VisualStyle(color: DesignAssetColors.named("KeywordLeech"), symbolName: "drop.fill")
        public static let nature = VisualStyle(color: DesignAssetColors.named("KeywordNature"), symbolName: "leaf.fill")
        public static let freeze = VisualStyle(color: DesignAssetColors.named("KeywordFreeze"), symbolName: "snowflake", prefersDarkForeground: true)
        public static let dodge = VisualStyle(color: DesignAssetColors.named("KeywordDodge"), symbolName: "arrowshape.turn.up.left.circle.fill")
        public static let purge = VisualStyle(color: DesignAssetColors.named("KeywordPurge"), symbolName: "sparkles")
        public static let mana = VisualStyle(color: DesignAssetColors.named("KeywordMana"), symbolName: "star.fill")
        public static let deathsDoor = VisualStyle(
            color: DesignAssetColors.named("KeywordDeathsDoor"),
            symbolName: "heart.slash.fill"
        )
    }

    var visualStyle: VisualStyle {
        switch self {
        case .physical: return .physical
        case .burn: return .burn
        case .stun: return .stun
        case .block: return .block
        case .armor: return .armor
        case .health: return .health
        case .gold: return .gold
        case .holy: return .holy
        case .poison: return .poison
        case .bleed: return .bleed
        case .leech: return .leech
        case .nature: return .nature
        case .freeze: return .freeze
        case .dodge: return .dodge
        case .purge: return .purge
        case .mana: return .mana
        case .deathsDoor: return .deathsDoor
        }
    }
}
