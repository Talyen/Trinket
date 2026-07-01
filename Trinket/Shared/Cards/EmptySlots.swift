import SwiftUI

struct EmptyAbilitySlotCard: View {
    let tier: AbilityTier
    var reservesLabelSpace: Bool = true

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
                .trinketCardLabelSpace(reservesLabelSpace)
        }
        .accessibilityElement(children: .combine)
    }
}

struct EmptyItemSlotCard: View {
    let slot: ItemSlot
    var reservesLabelSpace: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    if let imageName = slot.slotBackgroundReference?.imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        TrinketDesign.cardShape
                            .fill(TrinketDesign.Colors.appBackground)
                    }
                }
                .clipShape(TrinketDesign.cardShape)
                .trinketCardSurface()

            Text("Empty \(slot.rawValue)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .trinketCardLabelSpace(reservesLabelSpace)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Empty \(slot.rawValue) slot")
    }
}
