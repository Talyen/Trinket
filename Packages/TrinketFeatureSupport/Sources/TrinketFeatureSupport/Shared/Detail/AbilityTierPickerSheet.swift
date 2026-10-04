import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

public struct AbilityTierPickerSheet: View {
    @Environment(\.scenePhase) private var scenePhase

    let combatant: Combatant
    let tier: AbilityTier
    let selectedAbilityID: String?
    let onSelectAbility: (Ability) -> Bool

    @State private var selectedAbility: Ability?
    @State private var requestedAbility: Ability?
    @State private var loadingAbility: Ability?

    public init(
        combatant: Combatant,
        tier: AbilityTier,
        selectedAbilityID: String?,
        onSelectAbility: @escaping (Ability) -> Bool,
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
            onSelect: { requestedAbility = $0 },
            onLongPress: { requestedAbility = $0 },
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
                .overlay(alignment: .topTrailing) {
                    if loadingAbility == ability, requestedAbility == ability {
                        ProgressView()
                            .padding(TrinketDesign.Spacing.small)
                            .trinketMaterial(.subtleOverlay)
                            .padding(TrinketDesign.Spacing.extraSmall)
                            .accessibilityLabel("Preparing ability")
                    }
                }
                .overlay {
                    TrinketDesign.cardShape
                        .strokeBorder(TrinketDesign.Colors.accent, lineWidth: 2)
                        .opacity(requestedAbility == ability ? 0.7 : 0)
                        .animation(TrinketMotion.Interaction.selection, value: requestedAbility)
                }
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
                    guard onSelectAbility(ability) else { return }
                    selectedAbility = nil
                },
            )
        }
        .preparingArtwork(request: $requestedAbility, presentation: $selectedAbility) {
            [$0.artReference?.imageName, $0.artReference?.thumbnailImageName].compactMap(\.self)
        }
        .task(id: requestedAbility) {
            loadingAbility = nil
            guard let ability = requestedAbility else { return }
            do {
                try await Task.sleep(for: .seconds(TrinketMotion.Interaction.pendingIndicatorDelay))
                try Task.checkCancellation()
                guard requestedAbility == ability else { return }
                loadingAbility = ability
            } catch {}
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                requestedAbility = nil
                loadingAbility = nil
            }
        }
    }
}
