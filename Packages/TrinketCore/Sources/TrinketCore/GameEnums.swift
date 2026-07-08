import Foundation

public enum Keyword: String, CaseIterable, Identifiable, Hashable, Sendable {
    case physical = "Physical"
    case burn = "Burn"
    case stun = "Stun"
    case block = "Block"
    case armor = "Armor"
    case health = "Health"
    case gold = "Gold"
    case holy = "Holy"
    case poison = "Poison"
    case bleed = "Bleed"
    case leech = "Leech"
    case nature = "Nature"
    case freeze = "Freeze"
    case dodge = "Dodge"
    case purge = "Purge"
    case mana = "Mana"
    case deathsDoor = "Death's Door"

    public var id: String {
        rawValue
    }

    public enum Category: String, CaseIterable {
        case damageType = "Damage Type"
        case mitigation = "Mitigation"
        case restoration = "Restoration"
        case resource = "Resource"
    }

    public var category: Category {
        switch self {
        case .physical, .burn, .poison, .bleed, .holy, .nature, .freeze, .stun: return .damageType
        case .block, .armor, .dodge, .purge: return .mitigation
        case .health, .leech, .deathsDoor: return .restoration
        case .gold, .mana: return .resource
        }
    }

    /// Player-facing status label for control effects and DoT effects. Shares styling with the parent keyword.
    public var statusAlias: String? {
        switch self {
        case .freeze: return "Frozen"
        case .stun: return "Stunned"
        case .burn: return "Burning"
        case .poison: return "Poisoned"
        case .bleed: return "Bleeding"
        case .deathsDoor: return "Death's Door"
        default: return nil
        }
    }

    public static let styledTerms: [(term: String, keyword: Keyword)] = {
        var terms: [(String, Keyword)] = allCases.map { ($0.rawValue, $0) }
        for keyword in allCases {
            if let alias = keyword.statusAlias {
                terms.append((alias, keyword))
            }
        }
        return terms.sorted { $0.0.count > $1.0.count }
    }()

    public var rulesText: String {
        switch self {
        case .physical:
            return "Direct weapon or body damage."
        case .burn:
            return "Fire damage over time."
        case .stun:
            return "Stun damage builds up; at 20% of max HP the target becomes Stunned and loses their next action."
        case .block:
            return "Damage absorption shield layered on top of health."
        case .armor:
            return "Damage mitigation, reducing incoming damage by a percentage."
        case .health:
            return "Survivability and health restoration."
        case .gold:
            return "Currency for shops or upgrades."
        case .holy:
            return "Radiant holy damage type."
        case .poison:
            return "Toxic damage over time."
        case .bleed:
            return "Physical damage over time from bleeding wounds."
        case .leech:
            return "Damage that restores health to the attacker."
        case .nature:
            return "Nature and growth damage type."
        case .freeze:
            return "Freeze damage builds up; at 20% of max HP the target becomes Frozen and loses their next action."
        case .dodge:
            return "Chance to avoid incoming damage entirely."
        case .purge:
            return "Instantly removes beneficial status effects from enemies."
        case .mana:
            return "Magical energy used to power abilities."
        case .deathsDoor:
            return "Hanging by a thread after a near-fatal blow. Heal soon or the next fatal hit will end them."
        }
    }
}

public enum Rarity: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case basic
    case astral

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .basic: return "Basic"
        case .astral: return "Astral"
        }
    }
}

public enum AbilityTier: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case basic = "Basic"
    case skill = "Skill"
    case ultimate = "Ultimate"

    public var id: String {
        rawValue
    }

    public var cadenceTurns: Int {
        switch self {
        case .basic:
            return 1
        case .skill:
            return 3
        case .ultimate:
            return 6
        }
    }

    public var unlockLevel: Int {
        switch self {
        case .basic:
            return 1
        case .skill:
            return 1
        case .ultimate:
            return 6
        }
    }

    public var unlockLabel: String {
        "Unlocks at Level \(unlockLevel)"
    }
}

public extension AbilityTier {
    var symbolName: String {
        switch self {
        case .basic:
            return "circle.fill"
        case .skill:
            return "sparkles"
        case .ultimate:
            return "star.fill"
        }
    }

    var cadenceLabel: String {
        switch self {
        case .basic:
            return "Every turn"
        case .skill:
            return "Every 3 turns"
        case .ultimate:
            return "Every 6 turns"
        }
    }
}

public enum ItemSlot: String, CaseIterable, Identifiable, Hashable, Sendable {
    case weapon = "Weapon"
    case armor = "Armor"
    case trinket = "Trinket"
    case secondaryTrinket = "Secondary Trinket"

    public var id: String {
        rawValue
    }

    /// The item catalog slot used to populate this equipment slot.
    public var baseItemSlot: ItemSlot {
        switch self {
        case .secondaryTrinket:
            return .trinket
        default:
            return self
        }
    }

    public var displayName: String {
        switch self {
        case .secondaryTrinket:
            return ItemSlot.trinket.rawValue
        default:
            return rawValue
        }
    }

    public var accessibilityIdentifier: String {
        "\(rawValue) item slot"
    }

    public var symbolName: String {
        switch self {
        case .weapon:
            return "wand.and.sparkles"
        case .armor:
            return "shield.fill"
        case .trinket, .secondaryTrinket:
            return "diamond.fill"
        }
    }

    public var unlockLabel: String {
        switch self {
        case .weapon:
            return "Find a Weapon to Unlock"
        case .armor:
            return "Find Armor to Unlock"
        case .trinket, .secondaryTrinket:
            return "Find a Trinket to Unlock"
        }
    }

    public func accepts(_ baseTypeSlot: ItemSlot) -> Bool {
        baseTypeSlot == baseItemSlot
    }
}
