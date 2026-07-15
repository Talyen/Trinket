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
    var lockLabel: String?
    var reservesLabelSpace: Bool = true
    var artworkBlend: ArtworkBlend = .none

    private var isLocked: Bool {
        lockLabel != nil
    }

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    if let imageName = (slot.slotBackgroundReference ?? ItemSlot.trinket.slotBackgroundReference)?.imageName {
                        Image.preparedAsset(named: imageName)
                            .resizable()
                            .scaledToFill()
                            .trinketArtworkBlend(artworkBlend)
                    } else {
                        TrinketDesign.cardShape
                            .fill(TrinketDesign.Colors.surface)
                    }
                }
                .clipShape(TrinketDesign.cardShape)
                .trinketLockedCardEffect(isLocked: isLocked, text: isLocked ? "Locked" : nil)
                .trinketCardSurface()

            Text(title)
                .trinketTypography(.cardLabel)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TrinketDesign.Metrics.extraSmallSpacing)
                .trinketCardLabelSpace(reservesLabelSpace)
        }
    }

    private var title: String {
        isLocked ? slot.displayName : "Empty \(slot.displayName)"
    }
}
