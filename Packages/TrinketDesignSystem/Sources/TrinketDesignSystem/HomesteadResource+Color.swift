import SwiftUI
import TrinketCore

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
        case .crystal:
            DesignAssetColors.named("ResourceCrystal")
        case .gold:
            TrinketDesign.Colors.accent
        }
    }
}
