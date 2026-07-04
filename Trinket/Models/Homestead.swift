import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketCore
import TrinketContent

extension HomesteadResource {
    var displayName: String {
        switch self {
        case .wood: return "Wood"
        case .stone: return "Stone"
        case .iron: return "Iron"
        case .food: return "Food"
        case .herbs: return "Herbs"
        case .crystal: return "Crystal"
        case .gold: return "Gold"
        }
    }

    var symbolName: String {
        switch self {
        case .wood: return "tree.fill"
        case .stone: return "mountain.2.fill"
        case .iron: return "hammer.fill"
        case .food: return "carrot.fill"
        case .herbs: return "leaf.fill"
        case .crystal: return "sparkles"
        case .gold: return "dollarsign.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .wood: return .brown
        case .stone: return Color(red: 0.58, green: 0.54, blue: 0.48)
        case .iron: return Color(red: 0.30, green: 0.39, blue: 0.48)
        case .food: return .orange
        case .herbs: return .green
        case .crystal: return .blue
        case .gold: return Keyword.gold.visualStyle.color
        }
    }
}

extension HomesteadNodeDefinition {
    var tint: Color {
        tintStyle.color
    }
}
