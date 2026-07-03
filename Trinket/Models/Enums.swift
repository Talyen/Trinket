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

extension Keyword {
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
        static let dodge = VisualStyle(color: Color(red: 0.3, green: 0.7, blue: 0.9), symbolName: "arrowshape.turn.up.left.circle.fill")
        static let purge = VisualStyle(color: Color(red: 0.75, green: 0.55, blue: 1.0), symbolName: "sparkles")
        static let mana = VisualStyle(color: Color(red: 0.45, green: 0.15, blue: 1.0), symbolName: "star.fill")
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
        case .dodge: return .dodge
        case .purge: return .purge
        case .mana: return .mana
        }
    }
}

extension ItemSlot {
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
