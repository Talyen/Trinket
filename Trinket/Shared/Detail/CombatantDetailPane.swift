import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct CombatantDetailPane: View {
    let combatant: Combatant
    let progression: CombatantProgression
    @Binding var loadout: AbilityLoadout
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState
    let allowsEditing: Bool
    var battleHealth: Int?
    var activeEffectSummaries: [EffectSummary] = []
    var hidesNavigationBar = false

    @Environment(\.dismiss) private var dismiss

    /// Sub-picker navigation state — owned here at the pane level so the
    /// navigationDestination modifiers are at the root of whatever NavigationStack
    /// is presenting this view. No nested UISheetPresentationControllers.
    @State private var selectedItemSlot: ItemSlot?
    @State private var selectedAbilityTier: AbilityTier?

    private var combatBuild: CombatBuild {
        CombatBuildResolver.build(
            combatant: combatant,
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryState.items
        )
    }

    private var heroOrPetTrait: CombatantTraitDefinition? {
        GameContent.trait(forCombatantID: combatant.id)
    }

    private var enemyTraits: [CombatantTraitDefinition] {
        guard combatant.role == .enemy,
              let enemy = GameContent.enemy(matching: combatant.id)
        else { return [] }
        return GameContent.traits(for: enemy)
    }

    private var effectiveCombatant: Combatant {
        combatBuild.combatant
    }

    var body: some View {
        DetailHeroScrollShell(
            title: combatant.name,
            // Sheet hosts use `.presentationContentInteraction(.resizes)`, so swipe
            // alone won't dismiss — mirror ItemDetailView with an explicit Done.
            showsDoneButton: !hidesNavigationBar,
            hidesNavigationBar: hidesNavigationBar,
            onDone: { dismiss() },
            header: { baseHeight, overscroll in
                CombatantHeroHeader(
                    combatant: combatant,
                    progression: progression,
                    baseHeight: baseHeight,
                    overscroll: overscroll
                )
                .accessibilityIdentifier("\(combatant.name) detail hero header")
            },
            bodyContent: {
            DetailSection("Stats", sectionID: AccessibilityID.CombatantDetail.statsSection) {
                statRow(
                    "Health",
                    value: "\(currentHealth)/\(combatBuild.effectiveMaxHealth)",
                    accessibilityIdentifier: AccessibilityID.CombatantDetail.healthStat
                )
                if combatBuild.effectiveMaxMana > 0 {
                    statRow("Mana", value: "\(combatBuild.effectiveMaxMana) MP")
                }
                statRow("Strength", value: "\(effectiveCombatant.primaryStats.strength)")
                statRow("Agility", value: "\(effectiveCombatant.primaryStats.agility)")
                statRow("Toughness", value: "\(effectiveCombatant.primaryStats.toughness)")
                statRow("Intellect", value: "\(effectiveCombatant.primaryStats.intellect)")
                statRow("Wisdom", value: "\(effectiveCombatant.primaryStats.wisdom)")
            }

            if let heroOrPetTrait {
                traitSection(
                    title: "Trait",
                    traits: [heroOrPetTrait],
                    sectionID: AccessibilityID.CombatantDetail.traitSection,
                    descriptionID: AccessibilityID.CombatantDetail.traitDescription
                )
            }

            if !enemyTraits.isEmpty {
                traitSection(
                    title: "Traits",
                    traits: enemyTraits,
                    sectionID: AccessibilityID.CombatantDetail.enemyTraitsSection,
                    descriptionID: AccessibilityID.CombatantDetail.enemyTraitDescription
                )
            }

            if !activeEffectSummaries.isEmpty {
                DetailSection("Active Effects") {
                    ForEach(activeEffectSummaries) { summary in
                        KeywordDescriptionText(text: summary.text)
                            .trinketTypography(.secondaryBody)
                            .accessibilityElement(children: .combine)
                    }
                }
            }

            DetailSection("Abilities") {
                AbilitySummaryGrid(
                    combatant: combatant,
                    progression: progression,
                    loadout: $loadout,
                    allowsEditing: allowsEditing,
                    onSelectTier: allowsEditing ? { selectedAbilityTier = $0 } : nil
                )
                .padding(.vertical, 4)
            }

            DetailSection("Items") {
                EquipmentSlotSummaryGrid(
                    role: combatant.role,
                    equipmentLoadout: equipmentLoadout,
                    inventoryState: inventoryState,
                    onSelect: allowsEditing ? { selectedItemSlot = $0 } : nil
                )
                .padding(.vertical, 4)
            }
            }
        )
        // Sub-picker navigation — declared here so they land at the root of whichever
        // NavigationStack contains this pane (typically the Collection detail sheet).
        // This keeps all presentation at the stack root.
        .navigationDestination(item: $selectedItemSlot) { slot in
            ItemSlotPickerView(
                slot: slot,
                equipmentLoadout: $equipmentLoadout,
                inventoryState: $inventoryState
            )
        }
        .navigationDestination(item: $selectedAbilityTier) { tier in
            AbilityTierPickerSheet(
                combatant: combatant,
                tier: tier,
                loadout: $loadout
            )
        }
    }

    private func traitSection(
        title: String,
        traits: [CombatantTraitDefinition],
        sectionID: String,
        descriptionID: String
    ) -> some View {
        DetailSection(title, sectionID: sectionID) {
            ForEach(traits) { trait in
                VStack(alignment: .leading, spacing: 4) {
                    Text(trait.name)
                        .trinketTypography(.button)
                    KeywordDescriptionText(text: trait.description)
                        .trinketTypography(.secondaryBody)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(descriptionID)
                }
            }
        }
    }

    private var currentHealth: Int {
        battleHealth ?? combatBuild.effectiveMaxHealth
    }

    private func statRow(_ title: String, value: String, accessibilityIdentifier: String? = nil) -> some View {
        LabeledContent {
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        } label: {
            Text(title)
                .trinketTypography(.body)
                .foregroundStyle(.primary)
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }
}

extension CombatantDetailPane {
    init(
        snapshot: CombatantCardDetail,
        hidesNavigationBar: Bool = false
    ) {
        self.init(
            combatant: snapshot.combatant,
            progression: snapshot.progression,
            loadout: .constant(snapshot.combatant.abilityLoadout),
            equipmentLoadout: .constant(snapshot.equipmentLoadout),
            inventoryState: .constant(snapshot.inventoryState),
            allowsEditing: false,
            battleHealth: snapshot.health,
            activeEffectSummaries: snapshot.activeEffectSummaries,
            hidesNavigationBar: hidesNavigationBar
        )
    }
}
