import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

extension HomesteadResource {
    var displayName: String {
        switch self {
        case .wood: "Wood"
        case .stone: "Stone"
        case .iron: "Iron"
        case .food: "Food"
        case .herbs: "Herbs"
        case .crystal: "Crystal"
        case .gold: "Gold"
        }
    }

    var symbolName: String {
        switch self {
        case .wood: "tree.fill"
        case .stone: "mountain.2.fill"
        case .iron: "hammer.fill"
        case .food: "carrot.fill"
        case .herbs: "leaf.fill"
        case .crystal: "sparkles"
        case .gold: "dollarsign.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .wood: .brown
        case .stone: Color("ResourceStone", bundle: .main)
        case .iron: Color("ResourceIron", bundle: .main)
        case .food: .orange
        case .herbs: .green
        case .crystal: .blue
        case .gold: Keyword.gold.visualStyle.color
        }
    }
}

extension HomesteadNodeDefinition {
    var tint: Color {
        tintStyle.color
    }
}
