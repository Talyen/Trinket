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
        case .hide: "Hide"
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
        case .hide: "pawprint.fill"
        case .crystal: "sparkles"
        case .gold: "dollarsign.circle.fill"
        }
    }
}

extension HomesteadNodeDefinition {
    var tint: Color {
        tintStyle.color
    }
}
