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
    case freeze = "Freeze"
    case dodge = "Dodge"
    case purge = "Purge"
    case mana = "Mana"
    case deathsDoor = "Death's Door"

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
        case .physical, .burn, .poison, .bleed, .holy, .freeze, .stun: .damageType
        case .block, .armor, .dodge, .purge: .mitigation
        case .health, .leech, .deathsDoor: .restoration
        case .gold, .mana: .resource
        }
    }

    /// Damage types and restoration heals (Health / Leech) can critical.
    /// Mitigation, resources, and Death's Door never roll or scale critical chance.
    public var allowsCriticalHits: Bool {
        switch self {
        case .physical, .burn, .poison, .bleed, .holy, .freeze, .stun, .health, .leech:
            true
        case .block, .armor, .dodge, .purge, .gold, .mana, .deathsDoor:
            false
        }
    }

    /// Player-facing status label for control effects and DoT effects. Shares styling with the parent keyword.
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
            "Direct weapon or body damage."
        case .burn:
            "Fire damage over time."
        case .stun:
            "Stun damage builds up; at 20% of max HP the target becomes Stunned and loses their next action."
        case .block:
            "A pooled damage buffer absorbed before Health. Halves at the end of each round."
        case .armor:
            "Flat damage reduction up to half of each hit. Decays by 1 whenever damage is taken."
        case .health:
            "Survivability and health restoration."
        case .gold:
            "Currency for shops or upgrades."
        case .holy:
            "Radiant holy damage type."
        case .poison:
            "Toxic damage over time."
        case .bleed:
            "Physical damage over time from bleeding wounds."
        case .leech:
            "Damage that restores health to the attacker."
        case .freeze:
            "Freeze damage builds up; at 20% of max HP the target becomes Frozen and loses their next action."
        case .dodge:
            "Chance to avoid incoming damage entirely."
        case .purge:
            "Instantly removes beneficial status effects from enemies."
        case .mana:
            "Magical energy used to power abilities."
        case .deathsDoor:
            "Hanging by a thread after a near-fatal blow. Heal soon or the next fatal hit will end them."
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
        case .basic: "Basic"
        case .astral: "Astral"
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
            1
        case .skill:
            3
        case .ultimate:
            6
        }
    }

    public var unlockLevel: Int {
        switch self {
        case .basic:
            1
        case .skill:
            1
        case .ultimate:
            6
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
            "circle.fill"
        case .skill:
            "sparkles"
        case .ultimate:
            "star.fill"
        }
    }

    var cadenceLabel: String {
        switch self {
        case .basic:
            "Every turn"
        case .skill:
            "Every 3 turns"
        case .ultimate:
            "Every 6 turns"
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
            .trinket
        default:
            self
        }
    }

    public var displayName: String {
        switch self {
        case .secondaryTrinket:
            ItemSlot.trinket.rawValue
        default:
            rawValue
        }
    }

    public var accessibilityIdentifier: String {
        "\(rawValue) item slot"
    }

    public var symbolName: String {
        switch self {
        case .weapon:
            "wand.and.sparkles"
        case .armor:
            "shield.fill"
        case .trinket, .secondaryTrinket:
            "diamond.fill"
        }
    }

    public var unlockLabel: String {
        switch self {
        case .weapon:
            "Find a Weapon to Unlock"
        case .armor:
            "Find Armor to Unlock"
        case .trinket, .secondaryTrinket:
            "Find a Trinket to Unlock"
        }
    }

    public func accepts(_ baseTypeSlot: ItemSlot) -> Bool {
        baseTypeSlot == baseItemSlot
    }
}
