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

        public static let physical = Self(
            color: DesignAssetColors.named("KeywordPhysical"),
            symbolName: "burst.fill"
        )
        public static let burn = Self(
            color: DesignAssetColors.named("KeywordBurn"),
            secondaryColor: DesignAssetColors.named("KeywordPhysical"),
            symbolName: "flame.fill"
        )
        public static let stun = Self(
            color: DesignAssetColors.named("KeywordStun"),
            symbolName: "bolt.fill",
            prefersDarkForeground: true
        )
        public static let block = Self(
            color: DesignAssetColors.named("KeywordBlock"),
            symbolName: "shield.fill"
        )
        public static let health = Self(
            color: DesignAssetColors.named("KeywordHealth"),
            secondaryColor: TrinketDesign.Colors.health,
            symbolName: "heart.fill"
        )
        public static let gold = Self(
            color: DesignAssetColors.named("KeywordGold"),
            symbolName: "circle.circle.fill",
            prefersDarkForeground: true
        )
        public static let holy = Self(
            color: DesignAssetColors.named("KeywordHoly"),
            symbolName: "sun.max.fill",
            prefersDarkForeground: true
        )
        public static let poison = Self(
            color: DesignAssetColors.named("KeywordPoison"),
            symbolName: "drop.fill"
        )
        public static let bleed = Self(
            color: DesignAssetColors.named("KeywordBleed"),
            symbolName: "drop.fill"
        )
        public static let leech = Self(
            color: DesignAssetColors.named("KeywordLeech"),
            symbolName: "drop"
        )
        public static let freeze = Self(
            color: DesignAssetColors.named("KeywordFreeze"),
            symbolName: "snowflake",
            prefersDarkForeground: true
        )
        public static let dodge = Self(
            color: DesignAssetColors.named("KeywordDodge"),
            symbolName: "figure.run"
        )
        public static let purge = Self(
            color: DesignAssetColors.named("KeywordPurge"),
            symbolName: "shield.slash.fill"
        )
        public static let cleanse = Self(
            color: DesignAssetColors.named("KeywordCleanse"),
            symbolName: "sparkles"
        )
        public static let mana = Self(
            color: DesignAssetColors.named("KeywordMana"),
            symbolName: "moon.stars.fill"
        )
        public static let deathsDoor = Self(
            color: DesignAssetColors.named("KeywordDeathsDoor"),
            symbolName: "hourglass.bottomhalf.filled"
        )
        public static let beneficialStatus = Self(
            color: TrinketDesign.Colors.success,
            symbolName: "arrowshape.up.fill"
        )
        public static let negativeStatus = Self(
            color: TrinketDesign.Colors.destructive,
            symbolName: "arrowshape.down.fill"
        )
    }

    var visualStyle: VisualStyle {
        switch self {
        case .physical: .physical
        case .burn: .burn
        case .stun: .stun
        case .block: .block
        case .health: .health
        case .gold: .gold
        case .holy: .holy
        case .poison: .poison
        case .bleed: .bleed
        case .leech: .leech
        case .freeze: .freeze
        case .dodge: .dodge
        case .purge: .purge
        case .cleanse: .cleanse
        case .mana: .mana
        case .deathsDoor: .deathsDoor
        }
    }
}
