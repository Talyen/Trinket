import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct EquipmentSlotConfirmation {
    let id = UUID()
    let slots: Set<ItemSlot>
}

struct EquipmentSlotSummaryGrid: View {
    let role: Combatant.Role
    let equipmentLoadout: EquipmentLoadout
    let inventoryItems: [InventoryItem]
    let onSelect: ((ItemSlot) -> Void)?
    var onViewItem: ((InventoryItem) -> Void)?
    var requestedSlot: ItemSlot?
    var loadingSlot: ItemSlot?
    var confirmation: EquipmentSlotConfirmation?
    @State private var isVisible = false
    @State private var presentedConfirmationID: UUID?

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
                        slotCard(slot, equippedItemsByID: equippedItemsByID)
                            .overlay(alignment: .topTrailing) {
                                if loadingSlot == slot {
                                    ProgressView()
                                        .padding(TrinketDesign.Spacing.small)
                                        .trinketMaterial(.subtleOverlay)
                                        .padding(TrinketDesign.Spacing.extraSmall)
                                        .accessibilityLabel("Preparing equipment")
                                }
                            }
                            .overlay {
                                TrinketDesign.cardShape
                                    .strokeBorder(TrinketDesign.Colors.accent, lineWidth: 2)
                                    .opacity(requestedSlot == slot ? 0.7 : 0)
                                    .animation(TrinketMotion.Interaction.selection, value: requestedSlot)
                            }
                            .overlay {
                                TrinketDesign.cardShape
                                    .strokeBorder(TrinketDesign.Colors.accent, lineWidth: 2)
                                    .keyframeAnimator(
                                        initialValue: 0.0,
                                        trigger: presentedConfirmationID,
                                    ) { content, opacity in
                                        content.opacity(confirmation?.slots.contains(slot) == true ? opacity : 0)
                                    } keyframes: { _ in
                                        LinearKeyframe(0.8, duration: 0.08)
                                        LinearKeyframe(0.8, duration: TrinketMotion.Interaction.confirmationDuration)
                                        CubicKeyframe(0, duration: TrinketMotion.Content.fadeDuration)
                                    }
                            }
                    },
                )
            }
        }
        .onAppear {
            isVisible = true
            presentedConfirmationID = confirmation?.id
        }
        .onDisappear { isVisible = false }
        .onChange(of: confirmation?.id) { _, id in
            if isVisible {
                presentedConfirmationID = id
            }
        }
    }

    @ViewBuilder
    private func slotCard(_ slot: ItemSlot, equippedItemsByID: [String: InventoryItem]) -> some View {
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
