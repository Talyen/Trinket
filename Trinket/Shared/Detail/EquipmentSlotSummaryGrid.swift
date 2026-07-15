import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct EquipmentSlotSummaryGrid: View {
    let role: Combatant.Role
    let equipmentLoadout: EquipmentLoadout
    let inventoryState: PlayerInventoryState
    let onSelect: ((ItemSlot) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(role.equipmentSlots) { slot in
                if let onSelect, !isLocked(slot) {
                    Button {
                        onSelect(slot)
                    } label: {
                        itemSlot(for: slot)
                    }
                    .trinketQuietTapButtonStyle()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(slot.accessibilityIdentifier)

                } else {
                    itemSlot(for: slot)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .accessibilityIdentifier(slot.accessibilityIdentifier)
                }
            }
        }
    }

    @ViewBuilder
    private func itemSlot(for slot: ItemSlot) -> some View {
        if isLocked(slot) {
            EmptyItemSlotCard(
                slot: slot,
                lockLabel: slot.unlockLabel,
                reservesLabelSpace: false,
                artworkBlend: .perimeter(into: .surface)
            )
        } else if let item = inventoryState.item(matching: equipmentLoadout.itemID(for: slot)) {
            ItemCard(
                item: item,
                showsAffixCount: false,
                reservesLabelSpace: false,
                artworkBlend: .perimeter(into: .surface)
            )
        } else {
            EmptyItemSlotCard(
                slot: slot,
                reservesLabelSpace: false,
                artworkBlend: .perimeter(into: .surface)
            )
        }
    }

    private func isLocked(_ slot: ItemSlot) -> Bool {
        !inventoryState.hasItem(for: slot)
    }
}
