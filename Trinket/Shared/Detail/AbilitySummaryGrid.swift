import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct AbilitySummaryGrid: View {
    let combatant: Combatant
    let progression: CombatantProgression
    @Binding var loadout: AbilityLoadout
    let allowsEditing: Bool
    /// Called by the parent when the user taps an editable ability slot. The parent owns
    /// the navigation/presentation so no nested sheet is needed here.
    var onSelectTier: ((AbilityTier) -> Void)?
    /// Called when viewing (not editing) and the user taps a filled ability slot.
    var onViewAbility: ((Ability) -> Void)?

    var body: some View {
        SlotSummaryGrid(
            slots: AbilityTier.allCases,
            isLocked: isLocked,
            hasItem: { selectedAbility(for: $0) != nil },
            onSelect: allowsEditing ? onSelectTier : nil,
            onView: !allowsEditing ? { tier in
                if let ability = selectedAbility(for: tier) {
                    onViewAbility?(ability)
                }
            } : nil,
            accessibilityIdentifier: { "\($0.rawValue) ability slot" },
            card: { tier in
                if let ability = selectedAbility(for: tier) {
                    AbilityChoiceCard(
                        ability: ability,
                        lockLabel: lockLabel(for: tier)
                    )
                } else {
                    EmptyAbilitySlotCard(tier: tier)
                }
            }
        )
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
}
