import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct EmptyAbilitySlotCard: View {
    let tier: AbilityTier
    var reservesLabelSpace: Bool = true

    var body: some View {
        ProductCardShell(
            showsLabel: true,
            reservesLabelSpace: reservesLabelSpace,
            art: {
                PlaceholderArtwork(.ability)
            },
            label: {
                Text(balanced: String(localized: L10n.ui_emptyslots_empty_1_83ed8("\(tier.rawValue)")))
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .trinketFittedText()
            },
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
                Text(balanced: String(localized: L10n.ui_emptyslots_empty_1_83ed8("\(slot.displayName)")))
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .trinketFittedText()
            },
        )
    }
}
