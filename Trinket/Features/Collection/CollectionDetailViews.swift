import SwiftUI

struct ExperienceProgressDetail: View {
    let progression: CombatantProgression

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("\(progression.currentXP)/\(progression.requiredXP) XP") {
                Text("\(Int(progression.progressFraction * 100))%")
                    .font(.footnote.monospacedDigit().weight(.bold))
                    .foregroundStyle(TrinketDesign.Colors.progression)
            }

            ProgressView(value: progression.progressFraction)
                .tint(TrinketDesign.Colors.progression)
                .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

struct AbilitySummaryGrid: View {
    let combatant: Combatant
    @Binding var loadout: AbilityLoadout
    let allowsEditing: Bool
    @State private var selectedAbilityTier: AbilityTier?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AbilityTier.allCases) { tier in
                if allowsEditing {
                    Button {
                        selectedAbilityTier = tier
                    } label: {
                        abilitySlot(for: tier)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("\(tier.rawValue) ability slot")
                    .accessibilityHint("Shows \(tier.rawValue) ability choices.")
                } else {
                    abilitySlot(for: tier)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("\(tier.rawValue) ability slot")
                        .accessibilityHint("Shows selected \(tier.rawValue) ability.")
                }
            }
        }
        .sheet(item: $selectedAbilityTier) { tier in
            NavigationStack {
                AbilityTierPickerSheet(
                    combatant: combatant,
                    tier: tier,
                    loadout: $loadout
                )
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func abilitySlot(for tier: AbilityTier) -> some View {
        Group {
            if let ability = selectedAbility(for: tier) {
                AbilityChoiceCard(ability: ability)
            } else {
                EmptyAbilitySlotCard(tier: tier)
            }
        }
    }

    private func selectedAbility(for tier: AbilityTier) -> Ability? {
        if let selected = loadout.ability(for: tier) {
            return selected
        }

        return combatant.abilityChoices.abilities(for: tier).first
    }
}

struct EquipmentSlotSummaryGrid: View {
    let equipmentLoadout: EquipmentLoadout
    let inventoryState: PlayerInventoryState
    let onSelect: ((ItemSlot) -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ItemSlot.allCases) { slot in
                if let onSelect {
                    Button {
                        onSelect(slot)
                    } label: {
                        itemSlot(for: slot)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("\(slot.rawValue) item slot")
                    .accessibilityHint("Shows \(slot.rawValue) items.")
                } else {
                    itemSlot(for: slot)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("\(slot.rawValue) item slot")
                        .accessibilityHint("Shows equipped \(slot.rawValue) item.")
                }
            }
        }
    }

    private func itemSlot(for slot: ItemSlot) -> some View {
        Group {
            if let item = inventoryState.item(matching: equipmentLoadout.itemID(for: slot)) {
                ItemCard(item: item, showsAffixCount: false)
            } else {
                EmptyItemSlotCard(slot: slot)
            }
        }
    }
}

struct AbilityTierPickerSheet: View {
    let combatant: Combatant
    let tier: AbilityTier
    @Binding var loadout: AbilityLoadout
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAbilityID: String? = nil

    private var abilities: [Ability] {
        combatant.abilityChoices.abilities(for: tier)
    }

    var body: some View {
        List {
            Section {
                ForEach(abilities) { ability in
                    Button {
                        selectedAbilityID = ability.id
                        loadout = loadout.selecting(ability)
                        dismiss()
                    } label: {
                        let isSelected = ability.id == (selectedAbilityID ?? selectedAbility?.id)
                        HStack(spacing: 14) {
                            AbilityChoiceCard(ability: ability)
                            .frame(height: 133)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(ability.name)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                KeywordDescriptionText(text: ability.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(TrinketDesign.Colors.selection)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(tier.rawValue) \(ability.name) ability card")
                    .accessibilityValue(ability.id == (selectedAbilityID ?? selectedAbility?.id) ? "Selected" : "Available")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .sensoryFeedback(.selection, trigger: selectedAbilityID)
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle(tier.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedAbility: Ability? {
        if let selected = loadout.ability(for: tier),
           let ability = abilities.first(where: { $0.id == selected.id }) {
            return ability
        }

        return abilities.first
    }
}

struct ItemSlotPickerView: View {
    let slot: ItemSlot
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState
    @Environment(\.dismiss) private var dismiss
    @State private var itemOrder: [String] = []
    @State private var selectedItemID: String? = nil

    var body: some View {
        List {
            Section {
                ForEach(orderedItems) { item in
                    Button {
                        selectedItemID = item.id
                        equipmentLoadout.equip(item, in: slot)
                        dismiss()
                    } label: {
                        let isSelected = item.id == (selectedItemID ?? equipmentLoadout.itemID(for: slot))
                        HStack(spacing: 14) {
                            ItemCard(item: item, showsAffixCount: false)
                                .frame(height: 133)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.displayName)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)

                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(item.affixes.prefix(4)) { affix in
                                        Text(affix.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(TrinketDesign.Colors.selection)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Equip \(item.displayName)")
                    .accessibilityValue(equipmentLoadout.itemID(for: slot) == item.id ? "Equipped" : "Available")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .sensoryFeedback(.selection, trigger: selectedItemID)
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Equip \(slot.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if itemOrder.isEmpty {
                itemOrder = entrySortedItems.map(\.id)
            }
        }
    }

    private var orderedItems: [InventoryItem] {
        let items = inventoryState.items(for: slot)
        guard !itemOrder.isEmpty else { return entrySortedItems }

        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let ordered = itemOrder.compactMap { itemsByID[$0] }
        let orderedIDs = Set(itemOrder)
        let newItems = items.filter { !orderedIDs.contains($0.id) }
        return ordered + newItems
    }

    private var entrySortedItems: [InventoryItem] {
        let items = inventoryState.items(for: slot)
        guard
            let equippedID = equipmentLoadout.itemID(for: slot),
            let equippedItem = items.first(where: { $0.id == equippedID })
        else {
            return items
        }

        return [equippedItem] + items.filter { $0.id != equippedID }
    }
}

struct CombatantHealthDetail: View {
    let health: Int
    let maxHealth: Int
    let fillColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(health), total: Double(maxHealth))
                .tint(fillColor)
                .frame(maxWidth: .infinity)

            Text("\(health)/\(maxHealth) HP")
                .font(.subheadline.monospacedDigit())
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }
}
