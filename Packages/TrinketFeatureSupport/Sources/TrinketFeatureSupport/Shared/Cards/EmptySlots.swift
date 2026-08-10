import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct EmptyAbilitySlotCard: View {
    let tier: AbilityTier
    var reservesLabelSpace: Bool = true

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize =
        TrinketDesign.Metrics.cardPlaceholderIconPointSize

    var body: some View {
        ProductCardShell(
            showsLabel: true,
            reservesLabelSpace: reservesLabelSpace,
            art: {
                ZStack {
                    TrinketDesign.cardShape
                        .fill(TrinketDesign.CardPlaceholderStyle.ability.color.opacity(0.18))
                    Image(systemName: TrinketDesign.CardPlaceholderStyle.ability.symbolName)
                        .font(.system(size: placeholderIconSize, weight: .semibold))
                        .foregroundStyle(TrinketDesign.CardPlaceholderStyle.ability.color)
                }
            },
            label: {
                Text("Empty \(tier.rawValue)")
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        )
    }
}

public struct EmptyItemSlotCard: View {
    let slot: ItemSlot
    var reservesLabelSpace: Bool = true

    public init(slot: ItemSlot, reservesLabelSpace: Bool = true) {
        self.slot = slot
        self.reservesLabelSpace = reservesLabelSpace
    }

    public var body: some View {
        ProductCardShell(
            showsLabel: true,
            reservesLabelSpace: reservesLabelSpace,
            art: {
                if let imageName = (slot.slotBackgroundReference ?? slot.baseItemSlot.slotBackgroundReference)?.imageName {
                    Image.preparedAsset(named: imageName)
                        .resizable()
                        .scaledToFill()
                        .decorativePreparedArtwork()
                } else {
                    TrinketDesign.Colors.surface
                }
            },
            label: {
                Text("Empty \(slot.displayName)")
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        )
    }
}
