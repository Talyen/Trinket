import SwiftUI

enum GameMode: String, CaseIterable, Identifiable {
    case battle = "Battle"

    var id: String { rawValue }

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

    var id: String { rawValue }

    var rulesText: String {
        switch self {
        case .physical:
            return "Direct weapon or body damage."
        case .burn:
            return "Damage over time on the enemy."
        }
    }

    struct VisualStyle {
        let color: Color
        let symbolName: String

        static let physical = VisualStyle(color: Color.orange, symbolName: "bolt.fill")
        static let burn = VisualStyle(color: Color.red, symbolName: "flame.fill")
    }

    var visualStyle: VisualStyle {
        switch self {
        case .physical: return .physical
        case .burn: return .burn
        }
    }
}

enum AbilityTier: String, CaseIterable, Identifiable, Hashable {
    case basic = "Basic"
    case skill = "Skill"
    case ultimate = "Ultimate"

    var id: String { rawValue }

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

    var id: String { rawValue }

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
