import SwiftUI

struct EquipmentSlotSummaryGrid: View {
    let equipmentLoadout: EquipmentLoadout
    let inventoryState: PlayerInventoryState
    let onSelect: ((ItemSlot) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(ItemSlot.allCases) { slot in
                if let onSelect {
                    Button {
                        onSelect(slot)
                    } label: {
                        itemSlot(for: slot)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .accessibilityIdentifier("\(slot.rawValue) item slot")
                    .accessibilityHint("Shows \(slot.rawValue) items.")
                } else {
                    itemSlot(for: slot)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .accessibilityIdentifier("\(slot.rawValue) item slot")
                        .accessibilityHint("Shows equipped \(slot.rawValue) item.")
                }
            }
        }
    }

    private func itemSlot(for slot: ItemSlot) -> some View {
        Group {
            if let item = inventoryState.item(matching: equipmentLoadout.itemID(for: slot)) {
                ItemCard(item: item, showsAffixCount: false, reservesLabelSpace: false)
            } else {
                EmptyItemSlotCard(slot: slot, reservesLabelSpace: false)
            }
        }
    }
}
