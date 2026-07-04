import SwiftUI
import TrinketContent
import TrinketCore

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
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .accessibilityIdentifier(slot.accessibilityIdentifier)
                    .accessibilityHint("Shows \(slot.displayName) items.")
                } else {
                    itemSlot(for: slot)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .accessibilityIdentifier(slot.accessibilityIdentifier)
                        .accessibilityHint("Shows equipped \(slot.displayName) item.")
                }
            }
        }
    }

    private func itemSlot(for slot: ItemSlot) -> some View {
        Group {
            if isLocked(slot) {
                EmptyItemSlotCard(slot: slot, lockLabel: slot.unlockLabel, reservesLabelSpace: false)
            } else if let item = inventoryState.item(matching: equipmentLoadout.itemID(for: slot)) {
                ItemCard(item: item, showsAffixCount: false, reservesLabelSpace: false)
            } else {
                EmptyItemSlotCard(slot: slot, reservesLabelSpace: false)
            }
        }
    }

    private func isLocked(_ slot: ItemSlot) -> Bool {
        !inventoryState.hasItem(for: slot)
    }
}
