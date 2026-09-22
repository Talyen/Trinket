import SwiftUI
import TrinketCore

/// Resource tint. The matching icon and display name live alongside the domain
/// in `TrinketFeatureSupport/Models/Homestead.swift`; keep the two together.
public extension HomesteadResource {
    var productionNameColor: Color {
        switch self {
        case .iron, .stone: TrinketDesign.Colors.keywordPhysical
        case .food: TrinketDesign.Colors.keywordHealth
        default: tint
        }
    }

    var tint: Color {
        switch self {
        case .wood:
            TrinketDesign.Colors.resourceWood
        case .stone:
            TrinketDesign.Colors.resourceStone
        case .iron:
            TrinketDesign.Colors.resourceIron
        case .food:
            TrinketDesign.Colors.resourceFood
        case .herbs:
            TrinketDesign.Colors.resourceHerbs
        case .hide:
            TrinketDesign.Colors.resourceHide
        case .gems:
            TrinketDesign.Colors.resourceGems
        case .gold:
            TrinketDesign.Colors.accent
        }
    }
}
