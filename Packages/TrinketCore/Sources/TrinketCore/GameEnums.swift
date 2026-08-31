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
        case .block, .dodge, .purge: .mitigation
        case .health, .leech, .deathsDoor, .cleanse: .restoration
        case .gold, .mana: .resource
        }
    }

    public static var damageTypes: [Self] {
        allCases.filter { $0.category == .damageType }
    }

    public var allowsCriticalHits: Bool {
        switch self {
        case .physical, .burn, .poison, .bleed, .holy, .freeze, .stun, .health, .leech:
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
        case .physical, .gold, .holy, .mana, .deathsDoor: []
        }
    }

    public static let styledTerms: [(term: String, keyword: Self)] = {
        var terms: [(String, Self)] = allCases.map { ($0.rawValue, $0) }
        for keyword in allCases {
            if let alias = keyword.statusAlias {
                terms.append((alias, keyword))
            }
            for inflection in keyword.inflections {
                terms.append((inflection, keyword))
            }
        }
        var seen = Set<String>()
        var unique: [(String, Self)] = []
        for (term, keyword) in terms {
            let lower = term.lowercased()
            if !seen.contains(lower) {
                seen.insert(lower)
                unique.append((term, keyword))
            }
        }
        return unique.sorted { $0.0.count > $1.0.count }
    }()

    public static func referenced(in text: String) -> [Self] {
        var keywordFirstIndices: [Self: String.Index] = [:]
        for (term, keyword) in styledTerms {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: term))\\b"
            guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { continue }
            if let existing = keywordFirstIndices[keyword] {
                if range.lowerBound < existing {
                    keywordFirstIndices[keyword] = range.lowerBound
                }
            } else {
                keywordFirstIndices[keyword] = range.lowerBound
            }
        }
        return keywordFirstIndices
            .sorted { $0.value < $1.value }
            .map(\.key)
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
            "Block prevents Health damage and halves at the end of each round"
        case .health:
            "Health keeps you alive"
        case .gold:
            "Gold is currency for shops and upgrades"
        case .holy:
            "Holy is a direct damage type"
        case .poison:
            "Poison deals damage each round and fades slowly"
        case .bleed:
            "Bleed deals damage each round for 2 rounds"
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
            "Mana regenerates +1 each round. Spend 3 Mana to add +1 Burn or Freeze on a card"
        case .deathsDoor:
            "Death's Door survives a fatal blow at 1 Health and is immune to fatal blows while it lasts"
        }
    }
}

public enum EnemyFaction: String, CaseIterable, Identifiable, Hashable, Sendable {
    case mortal
    case beast
    case elemental
    case construct
    case undead
    case corrupted

    public var id: String {
        rawValue
    }
}

public enum Rarity: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case basic
    case astral
    case unique

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .basic: "Basic"
        case .astral: "Astral"
        case .unique: "Unique"
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
}

public enum ItemSlot: String, CaseIterable, Identifiable, Hashable, Sendable {
    case weapon = "Weapon"
    case secondaryWeapon = "Secondary Weapon"
    case armor = "Armor"
    case accessory = "Accessory"
    case secondaryAccessory = "Secondary Accessory"
    case trinket = "Trinket"
    case secondaryTrinket = "Secondary Trinket"

    public var id: String {
        rawValue
    }

    public var baseItemSlot: Self {
        switch self {
        case .secondaryWeapon:
            .weapon
        case .secondaryAccessory:
            .accessory
        case .secondaryTrinket:
            .trinket
        default:
            self
        }
    }

    public var displayName: String {
        switch self {
        case .secondaryWeapon:
            Self.weapon.rawValue
        case .secondaryAccessory:
            Self.accessory.rawValue
        case .secondaryTrinket:
            Self.trinket.rawValue
        default:
            rawValue
        }
    }

    public var accessibilityIdentifier: String {
        "\(rawValue) item slot"
    }

    public var symbolName: String {
        switch self {
        case .weapon, .secondaryWeapon:
            "wand.and.sparkles"
        case .armor:
            "shield.fill"
        case .accessory, .secondaryAccessory, .trinket, .secondaryTrinket:
            "diamond.fill"
        }
    }

    public func accepts(_ baseTypeSlot: Self) -> Bool {
        baseTypeSlot == baseItemSlot
    }
}

public extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
