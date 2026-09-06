import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public struct AbilityTierPickerSheet: View {
    let combatant: Combatant
    let tier: AbilityTier
    let selectedAbilityID: String?
    let onSelectAbility: (Ability) -> Void

    @State private var selectedAbility: Ability?

    public init(
        combatant: Combatant,
        tier: AbilityTier,
        selectedAbilityID: String?,
        onSelectAbility: @escaping (Ability) -> Void,
    ) {
        self.combatant = combatant
        self.tier = tier
        self.selectedAbilityID = selectedAbilityID
        self.onSelectAbility = onSelectAbility
    }

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

    public var body: some View {
        OptionPickerGrid(
            items: abilities,
            isSelected: { ability in
                ability.id == selectedAbilityID
            },
            onSelect: { selectedAbility = $0 },
            onLongPress: { selectedAbility = $0 },
            accessibilityIdentifier: { ability in
                AccessibilityID.LoadoutPicker.abilityCandidate(ability.id)
            },
            card: { ability, isSelected in
                let equippedKeywords = ability.presentationKeywords.isEmpty ? [Keyword.physical] : ability.presentationKeywords
                AbilityChoiceCard(
                    ability: ability,
                    isSelected: isSelected,
                    shine: isSelected ? .keywords(equippedKeywords) : .none,
                    shineLineWidth: 3,
                )
            },
        )
        .accessibilityIdentifier(AccessibilityID.LoadoutPicker.abilityGrid(tier.rawValue))
        .navigationTitle(tier.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedAbility) { ability in
            AbilityDetailView(
                ability: ability,
                primaryActionTitle: "Select Ability",
                primaryActionAccessibilityID: AccessibilityID.LoadoutPicker.selectAbility(ability.id),
                onPrimaryAction: {
                    onSelectAbility(ability)
                    selectedAbility = nil
                },
            )
        }
    }
}
