import SwiftUI

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
