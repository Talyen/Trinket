import Foundation
import TrinketCore

public enum CombatReaction: String, CaseIterable, Hashable, Sendable {
    case shatter, frostfire, rupture, toxicShock, consecration, venomflash

    public var displayName: String {
        switch self {
        case .shatter: "Shatter"
        case .frostfire: "Frostfire"
        case .rupture: "Rupture"
        case .toxicShock: "Toxic Shock"
        case .consecration: "Consecration"
        case .venomflash: "Venomflash"
        }
    }

    public var nameResource: LocalizedStringResource {
        ContentCopy.resource(displayName)
    }

    public var damageKeyword: Keyword {
        switch self {
        case .shatter: .physical
        case .rupture: .bleed
        case .consecration: .holy
        case .toxicShock: .poison
        case .frostfire, .venomflash: .burn
        }
    }

    public var preparationKeyword: Keyword {
        switch self {
        case .shatter, .frostfire: .freeze
        case .rupture, .toxicShock: .stun
        case .consecration: .bleed
        case .venomflash: .poison
        }
    }
}
