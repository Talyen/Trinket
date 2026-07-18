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
    /// Called when viewing (not editing) and the user taps a filled item slot.
    var onViewItem: ((InventoryItem) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
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

                } else if let onViewItem, !isLocked(slot), let item = equippedItem(for: slot) {
                    Button {
                        onViewItem(item)
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
                reservesLabelSpace: false
            )
        } else if let item = equippedItem(for: slot) {
            ItemCard(
                item: item,
                showsAffixCount: false,
                reservesLabelSpace: false
            )
        } else {
            EmptyItemSlotCard(
                slot: slot,
                reservesLabelSpace: false
            )
        }
    }

    private func equippedItem(for slot: ItemSlot) -> InventoryItem? {
        inventoryState.item(matching: equipmentLoadout.itemID(for: slot))
    }

    private func isLocked(_ slot: ItemSlot) -> Bool {
        !inventoryState.hasItem(for: slot)
    }
}
