import SwiftUI

enum GameMode: String, CaseIterable, Identifiable {
    case battle = "Battle"

    var id: String {
        rawValue
    }

    var subtitle: String {
        switch self {
        case .battle:
            return "Choose a Hero and Pet, then test simple Keyword abilities against an enemy."
        }
    }
}

enum Keyword: String, CaseIterable, Identifiable, Hashable {
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

    var id: String {
        rawValue
    }

    enum Category: String, CaseIterable {
        case damageType = "Damage Type"
        case mitigation = "Mitigation"
        case restoration = "Restoration"
        case resource = "Resource"
    }

    var category: Category {
        switch self {
        case .physical, .burn, .poison, .bleed, .holy, .nature, .freeze, .stun: return .damageType
        case .block, .armor: return .mitigation
        case .health, .leech: return .restoration
        case .gold: return .resource
        }
    }

    /// Player-facing status label for prevention and DoT effects. Shares styling with the parent keyword.
    var statusAlias: String? {
        switch self {
        case .freeze: return "Frozen"
        case .stun: return "Stunned"
        case .burn: return "Burning"
        case .poison: return "Poisoned"
        case .bleed: return "Bleeding"
        default: return nil
        }
    }

    static let styledTerms: [(term: String, keyword: Keyword)] = {
        var terms: [(String, Keyword)] = allCases.map { ($0.rawValue, $0) }
        for keyword in allCases {
            if let alias = keyword.statusAlias {
                terms.append((alias, keyword))
            }
        }
        return terms.sorted { $0.0.count > $1.0.count }
    }()

    var rulesText: String {
        switch self {
        case .physical:
            return "Direct weapon or body damage."
        case .burn:
            return "Fire damage over time."
        case .stun:
            return "Stun damage and Stunned prevention."
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
            return "Freeze damage and Frozen prevention."
        }
    }

    struct VisualStyle {
        let color: Color
        let symbolName: String

        static let physical = VisualStyle(color: Color.orange, symbolName: "bolt.fill")
        static let burn = VisualStyle(color: Color.red, symbolName: "flame.fill")
        static let stun = VisualStyle(color: Color.yellow, symbolName: "bolt.fill")
        static let block = VisualStyle(color: Color.blue, symbolName: "shield.fill")
        static let armor = VisualStyle(color: Color.gray, symbolName: "shield.lefthalf.filled")
        static let health = VisualStyle(color: Color.red, symbolName: "heart.fill")
        static let gold = VisualStyle(color: Color(red: 1.0, green: 0.85, blue: 0.3), symbolName: "dollarsign.circle.fill")
        static let holy = VisualStyle(color: Color(red: 1.0, green: 0.95, blue: 0.78), symbolName: "sun.max.fill")
        static let poison = VisualStyle(color: Color(red: 0.2, green: 0.6, blue: 0.2), symbolName: "drop.triangle.fill")
        static let bleed = VisualStyle(color: Color(red: 0.55, green: 0.0, blue: 0.0), symbolName: "drop.fill")
        static let leech = VisualStyle(color: Color(red: 0.85, green: 0.2, blue: 0.55), symbolName: "drop.fill")
        static let nature = VisualStyle(color: Color(red: 0.1, green: 0.7, blue: 0.4), symbolName: "leaf.fill")
        static let freeze = VisualStyle(color: Color(red: 0.6, green: 0.85, blue: 1.0), symbolName: "snowflake")
    }

    var visualStyle: VisualStyle {
        switch self {
        case .physical: return .physical
        case .burn: return .burn
        case .stun: return .stun
        case .block: return .block
        case .armor: return .armor
        case .health: return .health
        case .gold: return .gold
        case .holy: return .holy
        case .poison: return .poison
        case .bleed: return .bleed
        case .leech: return .leech
        case .nature: return .nature
        case .freeze: return .freeze
        }
    }
}

enum Rarity: String, CaseIterable, Identifiable, Hashable, Codable {
    case basic
    case astral

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .basic: return "Basic"
        case .astral: return "Astral"
        }
    }
}

enum AbilityTier: String, CaseIterable, Identifiable, Hashable {
    case basic = "Basic"
    case skill = "Skill"
    case ultimate = "Ultimate"

    var id: String {
        rawValue
    }

    var cadenceTurns: Int {
        switch self {
        case .basic:
            return 1
        case .skill:
            return 3
        case .ultimate:
            return 6
        }
    }

    var unlockLevel: Int {
        switch self {
        case .basic:
            return 1
        case .skill:
            return 3
        case .ultimate:
            return 6
        }
    }

    var unlockLabel: String {
        "Unlocks at Level \(unlockLevel)"
    }
}

extension AbilityTier {
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

enum ItemSlot: String, CaseIterable, Identifiable, Hashable {
    case weapon = "Weapon"
    case armor = "Armor"
    case trinket = "Trinket"

    var id: String {
        rawValue
    }

    var symbolName: String {
        switch self {
        case .weapon:
            return "wand.and.sparkles"
        case .armor:
            return "shield.fill"
        case .trinket:
            return "diamond.fill"
        }
    }

    struct VisualStyle {
        let accentColor: Color

        static let weapon = VisualStyle(accentColor: Color.red)
        static let armor = VisualStyle(accentColor: Color.blue)
        static let trinket = VisualStyle(accentColor: Color.purple)
    }

    var visualStyle: VisualStyle {
        switch self {
        case .weapon: return .weapon
        case .armor: return .armor
        case .trinket: return .trinket
        }
    }
}
