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
        VStack(alignment: .leading, spacing: TrinketDesign.Layout.sectionHeaderSpacing) {
            ForEach(slotRows, id: \.self) { row in
                SlotSummaryGrid(
                    slots: row,
                    isLocked: {
                        !equipmentLoadout.isAvailable($0, inventory: inventoryItems)
                    },
                    hasItem: { equippedItem(for: $0) != nil },
                    onSelect: onSelect,
                    onView: onViewItem != nil ? { slot in
                        if let item = equippedItem(for: slot) {
                            onViewItem?(item)
                        }
                    } : nil,
                    accessibilityIdentifier: { $0.accessibilityIdentifier },
                    card: { slot in
                        if let item = equippedItem(for: slot) {
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

    private func equippedItem(for slot: ItemSlot) -> InventoryItem? {
        inventoryItems.first { $0.id == equipmentLoadout.itemID(for: slot) }
    }
}
