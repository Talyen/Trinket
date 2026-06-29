import SwiftUI

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
