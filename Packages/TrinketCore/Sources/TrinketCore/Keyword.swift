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
        switch self {
        case .physical, .burn, .poison, .bleed, .holy, .freeze, .stun, .health, .leech, .thorns:
            true
        case .block, .dodge, .purge, .cleanse, .gold, .mana, .deathsDoor:
            false
        }
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

    public var rulesText: String {
        switch self {
        case .physical:
            "Physical is a direct damage type"
        case .burn:
            "Burn deals damage each round and fades quickly"
        case .stun:
            "Stun builds a meter; filling it makes the enemy lose an action"
        case .block:
            "Block prevents Health damage. Remaining Block halves after the enemy's turn for your party, and before the enemy's turn for enemies"
        case .health:
            "Health keeps you alive"
        case .gold:
            "Gold is currency for shops and upgrades"
        case .holy:
            "Holy is a direct damage type"
        case .poison:
            "Poison deals damage each round and fades slowly"
        case .bleed:
            "Bleed deals damage each round for 1 round"
        case .leech:
            "Leech damage heals the attacker"
        case .freeze:
            "Freeze builds a meter; filling it makes the enemy lose an action"
        case .dodge:
            "Dodge avoids an attack completely"
        case .purge:
            "Purge removes a helpful effect from an enemy"
        case .cleanse:
            "Cleanse removes a negative effect from a party member"
        case .mana:
            // Cost lives in BattleTurnEngine.manaEmpowermentCost/Bonus; the +1
            // bonus is Effect.manaEmpowermentBonus. Update together.
            "Mana regenerates +1 each round. Spend 3 Mana to add +1 Burn or Freeze on a card"
        case .deathsDoor:
            "Death's Door survives a fatal blow at 1 Health and is immune to fatal blows while it lasts"
        case .thorns:
            "Thorns deals damage back to attackers when hit"
        }
    }
}
