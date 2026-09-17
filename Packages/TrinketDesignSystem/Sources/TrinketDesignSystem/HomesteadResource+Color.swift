import SwiftUI
import TrinketCore

/// Resource tint. The matching icon and display name live alongside the domain
/// in `TrinketFeatureSupport/Models/Homestead.swift`; keep the two together.
public extension HomesteadResource {
    var tint: Color {
        switch self {
        case .wood:
            DesignAssetColors.named("ResourceWood")
        case .stone:
            DesignAssetColors.named("ResourceStone")
        case .iron:
            DesignAssetColors.named("ResourceIron")
        case .food:
            DesignAssetColors.named("ResourceFood")
        case .herbs:
            DesignAssetColors.named("ResourceHerbs")
        case .hide:
            DesignAssetColors.named("ResourceHide")
        case .gems:
            DesignAssetColors.named("ResourceGems")
        case .gold:
            TrinketDesign.Colors.accent
        }
    }
}
