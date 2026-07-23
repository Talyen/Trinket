import Foundation

public enum Keyword: String, CaseIterable, Identifiable, Hashable, Sendable {
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
        case .health, .leech, .deathsDoor: .restoration
        case .gold, .mana: .resource
        }
    }

    /// Keywords that can be selected by "Random damage" abilities.
    public static var damageTypes: [Keyword] {
        allCases.filter { $0.category == .damageType }
    }

    /// Damage types and restoration heals (Health / Leech) can critical.
    /// Mitigation, resources, and Death's Door never roll or scale critical chance.
    public var allowsCriticalHits: Bool {
        switch self {
        case .physical, .burn, .poison, .bleed, .holy, .freeze, .stun, .health, .leech:
            true
        case .block, .dodge, .purge, .gold, .mana, .deathsDoor:
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
            "Physical direct damage type"
        case .burn:
            "Burn deals damage each turn and fades quickly"
        case .stun:
            "Stun damage builds up and eventually causes the loss of a turn"
        case .block:
            "Prevents Health damage and fades quickly"
        case .health:
            "Health keeps you alive"
        case .gold:
            "Gold is currency for shops and upgrades"
        case .holy:
            "Holy direct damage type"
        case .poison:
            "Poison deals damage each turn and fades slowly"
        case .bleed:
            "Bleed deals damage each turn for 3 turns"
        case .leech:
            "Leech damage heals the attacker"
        case .freeze:
            "Freeze damage builds up and eventually causes the loss of a turn"
        case .dodge:
            "Dodge avoids an attack completely"
        case .purge:
            "Purge removes a beneficial effect"
        case .mana:
            "Mana regenerates +1 each turn and is spent to empower Burn and Freeze ability damage"
        case .deathsDoor:
            "Death's Door survives a fatal blow at 1 HP — heal before it ends or the next fatal hit kills"
        }
    }

    /// URL scheme for in-app keyword glossary links (`trinket-keyword://burn`).
    public static let glossaryURLScheme = "trinket-keyword"

    public var glossaryURL: URL {
        var components = URLComponents()
        components.scheme = Self.glossaryURLScheme
        components.host = glossaryHost
        if let url = components.url {
            return url
        }
        preconditionFailure("Keyword glossary URL must form for host \(glossaryHost)")
    }

    public init?(glossaryURL url: URL) {
        guard url.scheme == Self.glossaryURLScheme,
              let host = url.host,
              let keyword = Self.allCases.first(where: { $0.glossaryHost == host })
        else {
            return nil
        }
        self = keyword
    }

    private var glossaryHost: String {
        String(describing: self)
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

    public func accepts(_ baseTypeSlot: ItemSlot) -> Bool {
        baseTypeSlot == baseItemSlot
    }
}
