import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct EquipmentSlotSummaryGrid: View {
    let role: Combatant.Role
    let equipmentLoadout: EquipmentLoadout
    let inventoryItems: [InventoryItem]
    let onSelect: ((ItemSlot) -> Void)?
    var onViewItem: ((InventoryItem) -> Void)?

    var body: some View {
        let equippedItemIDs = Set(equipmentLoadout.itemIDsBySlot.values)
        let equippedItemsByID = Dictionary(
            uniqueKeysWithValues: inventoryItems.lazy
                .filter { equippedItemIDs.contains($0.id) }
                .map { ($0.id, $0) },
        )

        VStack(alignment: .leading, spacing: TrinketDesign.Layout.sectionHeaderSpacing) {
            ForEach(slotRows, id: \.self) { row in
                SlotSummaryGrid(
                    slots: row,
                    isLocked: {
                        !equipmentLoadout.isAvailable($0, inventory: inventoryItems)
                    },
                    hasItem: { equippedItem(for: $0, in: equippedItemsByID) != nil },
                    onSelect: onSelect,
                    onView: onViewItem != nil ? { slot in
                        if let item = equippedItem(for: slot, in: equippedItemsByID) {
                            onViewItem?(item)
                        }
                    } : nil,
                    accessibilityIdentifier: { $0.accessibilityIdentifier },
                    card: { slot in
                        if let item = equippedItem(for: slot, in: equippedItemsByID) {
                            ItemCard(
                                item: item,
                                showsAffixCount: false,
                                reservesLabelSpace: false,
                            )
                        } else {
                            EmptyItemSlotCard(
                                slot: slot,
                                reservesLabelSpace: false,
                            )
                        }
                    },
                )
            }
        }
    }

    private var slotRows: [[ItemSlot]] {
        let slots = role.equipmentSlots
        return stride(from: 0, to: slots.count, by: 3).map { start in
            Array(slots[start ..< min(start + 3, slots.count)])
        }
    }

    private func equippedItem(
        for slot: ItemSlot,
        in equippedItemsByID: [String: InventoryItem],
    ) -> InventoryItem? {
        equipmentLoadout.itemID(for: slot).flatMap { equippedItemsByID[$0] }
    }
}
