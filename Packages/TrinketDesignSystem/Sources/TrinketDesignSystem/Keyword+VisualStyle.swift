import SwiftUI
import TrinketCore

public extension Keyword {
    struct VisualStyle: Sendable {
        public let color: Color
        public let secondaryColor: Color
        public let glowColor: Color
        public let subtleBackgroundColor: Color
        public let borderColor: Color
        public let icon: GameIcon
        public let prefersDarkForeground: Bool

        public init(color: Color, secondaryColor: Color? = nil, icon: GameIcon, prefersDarkForeground: Bool = false) {
            self.color = color
            self.secondaryColor = secondaryColor ?? color.opacity(TrinketDesign.Opacity.secondary)
            glowColor = color.opacity(TrinketDesign.Opacity.glow)
            subtleBackgroundColor = color.opacity(TrinketDesign.Opacity.subtle)
            borderColor = color.opacity(TrinketDesign.Opacity.border)
            self.icon = icon
            self.prefersDarkForeground = prefersDarkForeground
        }

        public static let physical = Self(
            color: DesignAssetColors.named("KeywordPhysical"),
            icon: .system("burst.fill"),
        )
        public static let burn = Self(
            color: DesignAssetColors.named("KeywordBurn"),
            secondaryColor: DesignAssetColors.named("KeywordPhysical"),
            icon: .system("flame.fill"),
        )
        public static let stun = Self(
            color: DesignAssetColors.named("KeywordStun"),
            icon: .system("bolt.fill"),
            prefersDarkForeground: true,
        )
        public static let block = Self(
            color: DesignAssetColors.named("KeywordBlock"),
            icon: .system("shield.fill"),
        )
        public static let health = Self(
            color: DesignAssetColors.named("KeywordHealth"),
            secondaryColor: TrinketDesign.Colors.health,
            icon: .system("heart.fill"),
        )
        public static let gold = Self(
            color: TrinketDesign.Colors.accent,
            icon: .system("circle.circle.fill"),
            prefersDarkForeground: true,
        )
        public static let holy = Self(
            color: DesignAssetColors.named("KeywordHoly"),
            icon: .system("sun.max.fill"),
            prefersDarkForeground: true,
        )
        public static let poison = Self(
            color: DesignAssetColors.named("KeywordPoison"),
            icon: .system("flask.fill"),
        )
        public static let bleed = Self(
            color: DesignAssetColors.named("KeywordBleed"),
            icon: .system("drop.fill"),
        )
        public static let leech = Self(
            color: DesignAssetColors.named("KeywordLeech"),
            icon: .system("eyedropper"),
        )
        public static let freeze = Self(
            color: DesignAssetColors.named("KeywordFreeze"),
            icon: .system("snowflake"),
            prefersDarkForeground: true,
        )
        public static let dodge = Self(
            color: DesignAssetColors.named("KeywordDodge"),
            icon: .system("wind"),
            prefersDarkForeground: true,
        )
        public static let purge = Self(
            color: DesignAssetColors.named("KeywordPurge"),
            icon: .system("shield.slash.fill"),
        )
        public static let cleanse = Self(
            color: DesignAssetColors.named("KeywordCleanse"),
            icon: .system("sparkles"),
        )
        public static let mana = Self(
            color: DesignAssetColors.named("KeywordMana"),
            icon: .system("moon.stars.fill"),
        )
        public static let deathsDoor = Self(
            color: DesignAssetColors.named("KeywordDeathsDoor"),
            icon: .system("hourglass.bottomhalf.filled"),
        )
        public static let thorns = Self(
            color: DesignAssetColors.named("KeywordPhysical"),
            icon: .system("asterisk"),
        )
        public static let beneficialStatus = Self(
            color: TrinketDesign.Colors.success,
            icon: .system("arrowshape.up.fill"),
        )
        public static let negativeStatus = Self(
            color: TrinketDesign.Colors.destructive,
            icon: .system("arrowshape.down.fill"),
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
        case .thorns: .thorns
        }
    }
}
