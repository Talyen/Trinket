import Foundation
import TrinketCore

public enum CombatReaction: String, CaseIterable, Hashable, Sendable {
    case shatter, frostfire, rupture, toxicShock, consecration, bloodboil, venomflash

    public var displayName: String {
        switch self {
        case .shatter: "Shatter"
        case .frostfire: "Frostfire"
        case .rupture: "Rupture"
        case .toxicShock: "Toxic Shock"
        case .consecration: "Consecration"
        case .bloodboil: "Bloodboil"
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
        case .frostfire, .bloodboil, .venomflash: .burn
        }
    }

    public var preparationKeyword: Keyword {
        switch self {
        case .shatter, .frostfire: .freeze
        case .rupture, .toxicShock: .stun
        case .consecration, .bloodboil: .bleed
        case .venomflash: .poison
        }
    }
}
