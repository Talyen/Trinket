import SwiftUI
import TrinketContent
import TrinketCore

struct AbilitySummaryGrid: View {
    let combatant: Combatant
    let progression: CombatantProgression
    @Binding var loadout: AbilityLoadout
    let allowsEditing: Bool
    /// Called by the parent when the user taps an ability slot. The parent owns
    /// the navigation/presentation so no nested sheet is needed here.
    var onSelectTier: ((AbilityTier) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(AbilityTier.allCases) { tier in
                if allowsEditing, !isLocked(tier) {
                    Button {
                        onSelectTier?(tier)
                    } label: {
                        abilitySlot(for: tier)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .accessibilityIdentifier("\(tier.rawValue) ability slot")
                    .accessibilityHint("Shows \(tier.rawValue) ability choices.")
                } else {
                    abilitySlot(for: tier)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .accessibilityIdentifier("\(tier.rawValue) ability slot")
                        .accessibilityHint(accessibilityHint(for: tier))
                }
            }
        }
    }

    private func abilitySlot(for tier: AbilityTier) -> some View {
        Group {
            if let ability = selectedAbility(for: tier) {
                AbilityChoiceCard(ability: ability, lockLabel: lockLabel(for: tier))
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

    private func isLocked(_ tier: AbilityTier) -> Bool {
        combatant.role != .enemy && !progression.unlocks(tier)
    }

    private func lockLabel(for tier: AbilityTier) -> String? {
        isLocked(tier) ? tier.unlockLabel : nil
    }

    private func accessibilityHint(for tier: AbilityTier) -> String {
        if isLocked(tier) {
            return tier.unlockLabel
        }
        return "Shows selected \(tier.rawValue) ability."
    }
}
