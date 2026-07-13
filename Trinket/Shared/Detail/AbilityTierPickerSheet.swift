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
        ScrollView {
            LazyVGrid(
                columns: TrinketDesign.Metrics.partyPickerGridItems,
                spacing: TrinketDesign.Metrics.largeSpacing
            ) {
                ForEach(abilities) { ability in
                    optionButton(ability)
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
        }
        .accessibilityIdentifier(AccessibilityID.LoadoutPicker.abilityGrid(tier.rawValue))
        .navigationTitle(tier.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionButton(_ ability: Ability) -> some View {
        let isSelected = ability.id == selectedAbilityID

        return Button {
            onOpenDetail(ability)
        } label: {
            ZStack(alignment: .bottomLeading) {
                AbilityChoiceCard(
                    ability: ability,
                    showsName: false
                )

                TrinketHeroScrim.gradient(for: .detailHeader)
                    .clipShape(TrinketDesign.cardShape)

                Text(ability.name)
                    .trinketTypography(.cardTitle)
                    .trinketOnArtText(.title)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .padding(TrinketDesign.Metrics.mediumSpacing)

                if isSelected {
                    selectedCheckmark
                }
            }
            .clipShape(TrinketDesign.cardShape)
            .overlay {
                TrinketDesign.cardShape.strokeBorder(
                    isSelected ? TrinketDesign.Colors.selection : .clear,
                    lineWidth: isSelected ? 3 : 0
                )
            }
        }
        .buttonStyle(ArtworkNavigationCardButtonStyle())
        .accessibilityIdentifier(AccessibilityID.LoadoutPicker.abilityCandidate(ability.id))
    }

    private var selectedCheckmark: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinketDesign.Colors.selection)
                    .trinketGlassChip(.compact)
            }
            Spacer()
        }
        .padding(TrinketDesign.Metrics.smallSpacing)
    }
}
