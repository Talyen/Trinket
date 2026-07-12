import SwiftUI
import TrinketCore

public extension HomesteadTint {
    var color: Color {
        switch self {
        case .orange:
            DesignAssetColors.named("HomesteadTintOrange")
        case .green:
            DesignAssetColors.named("HomesteadTintGreen")
        case .yellow:
            DesignAssetColors.named("HomesteadTintYellow")
        case .mint:
            DesignAssetColors.named("HomesteadTintMint")
        case .cyan:
            DesignAssetColors.named("HomesteadTintCyan")
        case .indigo:
            DesignAssetColors.named("HomesteadTintIndigo")
        case .blue:
            DesignAssetColors.named("HomesteadTintBlue")
        }
    }
}
