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
        SlotSummaryGrid(
            slots: role.equipmentSlots,
            isLocked: { _ in false },
            hasItem: { equippedItem(for: $0) != nil },
            onSelect: onSelect,
            onView: onViewItem != nil ? { slot in
                if let item = equippedItem(for: slot) {
                    onViewItem?(item)
                }
            } : nil,
            accessibilityIdentifier: { $0.accessibilityIdentifier },
            combinesAccessibilityChildren: true,
            card: { slot in
                if let item = equippedItem(for: slot) {
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
        )
    }

    private func equippedItem(for slot: ItemSlot) -> InventoryItem? {
        inventoryState.item(matching: equipmentLoadout.itemID(for: slot))
    }
}
