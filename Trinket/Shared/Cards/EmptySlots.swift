import SwiftUI

struct EmptyAbilitySlotCard: View {
    let tier: AbilityTier

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    TrinketDesign.cardShape
                        .fill(TrinketDesign.CardPlaceholderStyle.ability.color.opacity(0.18))
                }
                .overlay {
                    Image(systemName: TrinketDesign.CardPlaceholderStyle.ability.symbolName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(TrinketDesign.CardPlaceholderStyle.ability.color)
                        .accessibilityHidden(true)
                }
                .trinketCardSurface()

            Text("Empty \(tier.rawValue)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .combine)
    }
}

struct EmptyItemSlotCard: View {
    let slot: ItemSlot

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    TrinketDesign.cardShape
                        .fill(TrinketDesign.CardPlaceholderStyle.item.color.opacity(0.18))
                }
                .overlay {
                    Image(systemName: TrinketDesign.CardPlaceholderStyle.item.symbolName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(TrinketDesign.CardPlaceholderStyle.item.color)
                        .accessibilityHidden(true)
                }
                .trinketCardSurface()

            Text("Empty \(slot.rawValue)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .frame(minHeight: TrinketDesign.Metrics.cardLabelReservedHeight, alignment: .center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Empty \(slot.rawValue) slot")
    }
}
