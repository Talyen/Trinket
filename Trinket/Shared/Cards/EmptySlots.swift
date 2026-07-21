import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct EmptyAbilitySlotCard: View {
    let tier: AbilityTier
    var reservesLabelSpace: Bool = true

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 38

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    TrinketDesign.cardShape
                        .fill(TrinketDesign.CardPlaceholderStyle.ability.color.opacity(0.18))
                }
                .overlay {
                    Image(systemName: TrinketDesign.CardPlaceholderStyle.ability.symbolName)
                        .font(.system(size: placeholderIconSize, weight: .semibold))
                        .foregroundStyle(TrinketDesign.CardPlaceholderStyle.ability.color)
                }
                .trinketCardSurface()

            Text("Empty \(tier.rawValue)")
                .trinketTypography(.cardLabel)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TrinketDesign.Metrics.extraSmallSpacing)
                .trinketCardLabelSpace(reservesLabelSpace)
        }
    }
}

struct EmptyItemSlotCard: View {
    let slot: ItemSlot
    var reservesLabelSpace: Bool = true

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    if let imageName = (slot.slotBackgroundReference ?? ItemSlot.trinket.slotBackgroundReference)?.imageName {
                        Image.preparedAsset(named: imageName)
                            .resizable()
                            .scaledToFill()
                            .decorativePreparedArtwork()
                    } else {
                        TrinketDesign.cardShape
                            .fill(TrinketDesign.Colors.surface)
                    }
                }
                .clipShape(TrinketDesign.cardShape)
                .trinketCardSurface()

            Text("Empty \(slot.displayName)")
                .trinketTypography(.cardLabel)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TrinketDesign.Metrics.extraSmallSpacing)
                .trinketCardLabelSpace(reservesLabelSpace)
        }
    }
}
