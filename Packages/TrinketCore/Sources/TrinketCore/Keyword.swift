import Foundation

public enum Keyword: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case physical = "Physical"
    case burn = "Burn"
    case stun = "Stun"
    case block = "Block"
    case health = "Health"
    case gold = "Gold"
    case holy = "Holy"
    case poison = "Poison"
    case bleed = "Bleed"
    case leech = "Leech"
    case freeze = "Freeze"
    case dodge = "Dodge"
    case purge = "Purge"
    case cleanse = "Cleanse"
    case mana = "Mana"
    case deathsDoor = "Death's Door"
    case thorns = "Thorns"

    public var id: String {
        rawValue
    }

    public enum Category: String, CaseIterable, Hashable, Sendable {
        case damageType = "Damage Type"
        case mitigation = "Mitigation"
        case restoration = "Restoration"
        case resource = "Resource"
    }

    public var category: Category {
        switch self {
        case .physical, .burn, .poison, .bleed, .holy, .freeze, .stun, .thorns: .damageType
        case .block, .dodge, .purge: .mitigation
        case .health, .leech, .deathsDoor, .cleanse: .restoration
        case .gold, .mana: .resource
        }
    }

    public static let damageTypes: [Self] = allCases.filter { $0.category == .damageType }

    /// Damage types plus Health and Leech roll crits (healing crits exist);
    /// resources and utility keywords never do.
    public var allowsCriticalHits: Bool {
        category == .damageType || self == .health || self == .leech
    }

    public var statusAlias: String? {
        switch self {
        case .freeze: "Frozen"
        case .stun: "Stunned"
        case .burn: "Burning"
        case .poison: "Poisoned"
        case .bleed: "Bleeding"
        case .deathsDoor: "Death's Door"
        default: nil
        }
    }

    public var statusName: String {
        statusAlias ?? rawValue
    }

    public var inflections: [String] {
        switch self {
        case .purge: ["Purges", "Purged", "Purging"]
        case .block: ["Blocks", "Blocked", "Blocking"]
        case .stun: ["Stuns", "Stunned", "Stunning"]
        case .cleanse: ["Cleanses", "Cleansed", "Cleansing"]
        case .dodge: ["Dodges", "Dodged", "Dodging"]
        case .freeze: ["Freezes", "Freezing", "Frozen"]
        case .burn: ["Burns", "Burned", "Burning"]
        case .bleed: ["Bleeds", "Bleeding"]
        case .poison: ["Poisons", "Poisoned", "Poisoning"]
        case .leech: ["Leeches", "Leeched", "Leeching"]
        case .health: ["Heals", "Healing", "Healed"]
        case .physical, .gold, .holy, .mana, .deathsDoor, .thorns: []
        }
    }

    /// Canonical English for headless consumers; the catalog owns displayed rule wording.
    public var rulesText: String {
        localizedRules(locale: Locale(identifier: "en")).text
    }
}
