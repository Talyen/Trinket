import SwiftUI
import TrinketCore

public struct TrinketRarityLabel: View {
    private let rarity: Rarity
    private let labelOverride: String?

    public init(rarity: Rarity, labelOverride: String? = nil) {
        self.rarity = rarity
        self.labelOverride = labelOverride
    }

    public var body: some View {
        Group {
            switch rarity {
            case .astral, .unique:
                premiumLabel
            case .basic:
                Text(displayLabel).foregroundStyle(.secondary)
            }
        }
        .trinketTypography(.eyebrow)
    }

    private var premiumColors: [Color] {
        switch rarity {
        case .astral:
            [
                TrinketDesign.Colors.arcane,
                TrinketDesign.Colors.informational,
            ]
        case .unique:
            [
                TrinketDesign.Colors.warning,
                TrinketDesign.Colors.warning.opacity(0.55),
            ]
        case .basic:
            []
        }
    }

    private var premiumShadowColor: Color {
        rarity == .astral ? TrinketDesign.Colors.arcane : TrinketDesign.Colors.warning
    }

    private var premiumLabel: some View {
        Text(displayLabel)
            .trinketShineText(colors: premiumColors)
            .shadow(color: premiumShadowColor.opacity(TrinketDesign.Opacity.glow), radius: 6)
    }

    private var displayLabel: String {
        (labelOverride ?? rarity.label).uppercased()
    }
}
