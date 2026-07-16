import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct AbilitySummaryGrid: View {
    let combatant: Combatant
    let progression: CombatantProgression
    @Binding var loadout: AbilityLoadout
    let allowsEditing: Bool
    /// Called by the parent when the user taps an ability slot. The parent owns
    /// the navigation/presentation so no nested sheet is needed here.
    var onSelectTier: ((AbilityTier) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: TrinketDesign.Metrics.sectionHeaderSpacing) {
            ForEach(AbilityTier.allCases) { tier in
                if allowsEditing, !isLocked(tier) {
                    Button {
                        onSelectTier?(tier)
                    } label: {
                        abilitySlot(for: tier)
                    }
                    .trinketQuietTapButtonStyle()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .accessibilityIdentifier("\(tier.rawValue) ability slot")

                } else {
                    abilitySlot(for: tier)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .accessibilityIdentifier("\(tier.rawValue) ability slot")
                }
            }
        }
    }

    @ViewBuilder
    private func abilitySlot(for tier: AbilityTier) -> some View {
        if let ability = selectedAbility(for: tier) {
            AbilityChoiceCard(
                ability: ability,
                lockLabel: lockLabel(for: tier),
                artworkBlend: .perimeter(into: .surface)
            )
        } else {
            EmptyAbilitySlotCard(tier: tier)
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
}
