import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct EmptyAbilitySlotCard: View {
    let tier: AbilityTier
    var reservesLabelSpace: Bool = true

    private var emptyLabel: LocalizedStringResource {
        switch tier {
        case .basic: L10n.ui_emptyslots_empty_basic
        case .skill: L10n.ui_emptyslots_empty_skill
        case .ultimate: L10n.ui_emptyslots_empty_ultimate
        }
    }

    var body: some View {
        ProductCardShell(
            showsLabel: true,
            reservesLabelSpace: reservesLabelSpace,
            art: {
                PlaceholderArtwork(.ability)
            },
            label: {
                Text(balanced: String(localized: emptyLabel))
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

    private var emptyLabel: LocalizedStringResource {
        switch slot {
        case .weapon, .secondaryWeapon: L10n.ui_emptyslots_empty_weapon
        case .armor: L10n.ui_emptyslots_empty_armor
        case .accessory, .secondaryAccessory: L10n.ui_emptyslots_empty_accessory
        case .trinket, .secondaryTrinket: L10n.ui_emptyslots_empty_trinket
        }
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
                Text(balanced: String(localized: emptyLabel))
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .trinketFittedText()
            },
        )
    }
}
