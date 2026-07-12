import SwiftUI
import TrinketCore

public extension HomesteadResource {
    /// Semantic tint for SF Symbol fallbacks and reward rows when raster art is absent.
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
        case .crystal:
            DesignAssetColors.named("ResourceCrystal")
        case .gold:
            Keyword.gold.visualStyle.color
        }
    }
}
