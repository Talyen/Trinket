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

    public static var damageTypes: [Self] {
        allCases.filter { $0.category == .damageType }
    }

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

    public static let highlightPattern: String = {
        let alternatives = styledTerms.map { NSRegularExpression.escapedPattern(for: $0.term) }
        return "\\b(?:\(alternatives.joined(separator: "|")))\\b"
    }()

    public static let termLookup: [String: Self] = {
        var lookup: [String: Self] = [:]
        for (term, keyword) in styledTerms {
            lookup[term.lowercased()] = keyword
        }
        return lookup
    }()

    public static let highlightRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: highlightPattern,
        options: [.caseInsensitive],
    )

    public static func referenced(in text: String) -> [Self] {
        guard let regex = highlightRegex else { return [] }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var keywordFirstIndices: [Self: Int] = [:]
        for match in regex.matches(in: text, options: [], range: fullRange) {
            let matched = nsText.substring(with: match.range).lowercased()
            guard let keyword = termLookup[matched] else { continue }
            if let existing = keywordFirstIndices[keyword] {
                if match.range.location < existing {
                    keywordFirstIndices[keyword] = match.range.location
                }
            } else {
                keywordFirstIndices[keyword] = match.range.location
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
            "Block prevents Health damage. Remaining Block halves after the enemy’s turn for your party, and before the enemy’s turn for enemies"
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
            "Mana regenerates +1 each round. Spend 3 Mana to add +1 Burn or Freeze on a card"
        case .deathsDoor:
            "Death's Door survives a fatal blow at 1 Health and is immune to fatal blows while it lasts"
        case .thorns:
            "Thorns deals damage back to attackers when hit"
        }
    }
}
