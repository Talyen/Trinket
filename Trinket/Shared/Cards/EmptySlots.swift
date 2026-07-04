import SwiftUI
import TrinketCore
import TrinketDesignSystem

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
    var lockLabel: String?
    var reservesLabelSpace: Bool = true

    private var isLocked: Bool {
        lockLabel != nil
    }

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    if let imageName = (slot.slotBackgroundReference ?? ItemSlot.trinket.slotBackgroundReference)?.imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        TrinketDesign.cardShape
                            .fill(TrinketDesign.Colors.appBackground)
                    }
                }
                .saturation(isLocked ? 0.15 : 1)
                .opacity(isLocked ? 0.65 : 1)
                .clipShape(TrinketDesign.cardShape)
                .overlay {
                    if let lockLabel {
                        TrinketDesign.cardShape
                            .fill(.black.opacity(0.35))
                        VStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.title3.weight(.semibold))
                            Text(lockLabel)
                                .font(.caption.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 8)
                        }
                        .foregroundStyle(.white)
                    }
                }
                .trinketCardSurface()

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .trinketCardLabelSpace(reservesLabelSpace)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if let lockLabel {
            return "\(slot.displayName) slot, \(lockLabel)"
        }
        return "Empty \(slot.displayName) slot"
    }

    private var title: String {
        isLocked ? slot.displayName : "Empty \(slot.displayName)"
    }
}
