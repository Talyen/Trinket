import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct AbilityTierPickerSheet: View {
    let combatant: Combatant
    let tier: AbilityTier
    let selectedAbilityID: String?
    let onOpenDetail: (Ability) -> Void

    private var abilities: [Ability] {
        let tierAbilities = combatant.abilityChoices.abilities(for: tier)
        guard
            let selectedAbilityID,
            let selected = tierAbilities.first(where: { $0.id == selectedAbilityID })
        else {
            return tierAbilities
        }

        return [selected] + tierAbilities.filter { $0.id != selectedAbilityID }
    }

    var body: some View {
        OptionPickerGrid(
            items: abilities,
            isSelected: { ability in
                ability.id == selectedAbilityID
            },
            onSelect: onOpenDetail,
            accessibilityIdentifier: { ability in
                AccessibilityID.LoadoutPicker.abilityCandidate(ability.id)
            },
            card: { ability, isSelected in
                AbilityChoiceCard(
                    ability: ability,
                    isSelected: isSelected
                )
            }
        )
        .accessibilityIdentifier(AccessibilityID.LoadoutPicker.abilityGrid(tier.rawValue))
        .navigationTitle(tier.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}
