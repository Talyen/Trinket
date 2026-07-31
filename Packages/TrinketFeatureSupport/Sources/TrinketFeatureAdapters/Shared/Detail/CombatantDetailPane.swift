import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

public struct CombatantDetailPane: View {
    @Environment(\.playSFX) private var playSFX

    let combatant: Combatant
    let progression: CombatantProgression
    @Binding var loadout: AbilityLoadout
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryItems: [InventoryItem]
    let allowsEditing: Bool
    let hapticsEnabled: Bool
    let effectsVolume: Double
    var battleHealth: Int?
    var activeEffectSummaries: [EffectSummary] = []
    var hidesNavigationBar = false

    /// Loadout picker navigation state is owned here at the pane level so the picker
    /// destinations are at the root of whatever NavigationStack presents this view.
    /// Each picker owns its detail destination so Back returns to that picker grid.
    @State private var selectedItemSlot: ItemSlot?
    @State private var selectedAbilityTier: AbilityTier?
    @State private var viewingAbility: ViewOnlyAbility?
    @State private var viewingItem: InventoryItem?
    @State private var selectionFeedbackTrigger = 0

    /// Distinct from `Ability` so view-only and loadout destinations do not collide.
    private struct ViewOnlyAbility: Hashable, Identifiable {
        let ability: Ability

        var id: String {
            ability.id
        }
    }

    private var resolvedCombatBuild: CombatBuild {
        CombatBuildResolver.build(
            combatant: combatant,
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryItems
        )
    }

    private var heroOrCompanionTrait: CombatantTraitDefinition? {
        GameContent.trait(forCombatantID: combatant.id)
    }

    private var enemyTraits: [CombatantTraitDefinition] {
        guard combatant.role == .enemy,
              let enemy = GameContent.enemy(matching: combatant.id)
        else { return [] }
        return GameContent.traits(for: enemy)
    }

    public var body: some View {
        let combatBuild = resolvedCombatBuild

        DetailHeroScrollShell(
            title: combatant.name,
            hidesNavigationBar: hidesNavigationBar
        ) { baseHeight, overscroll in
            DetailHeroHeader(
                eyebrow: combatant.role.rawValue.uppercased(),
                title: combatant.name,
                baseHeight: baseHeight,
                overscroll: overscroll
            ) {
                CombatantArtwork(combatant: combatant)
            } footer: {
                HStack {
                    Text("LEVEL \(progression.level)")
                        .trinketTypography(.eyebrow)
                        .trinketOnArtText(.eyebrow)

                    Text("\(progression.currentXP)/\(progression.requiredXP) XP")
                        .trinketTypography(.eyebrow)
                        .monospacedDigit()
                        .trinketOnArtText(.eyebrow)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("\(combatant.name) detail hero header")
        } bodyContent: {
            combatantDetailBody(combatBuild: combatBuild)
        }
        // Sub-picker navigation is declared here so it lands at the root of whichever
        // NavigationStack contains this pane (typically the Collection detail sheet).
        .navigationDestination(item: $selectedItemSlot) { slot in
            ItemSlotPickerView(
                slot: slot,
                equipmentLoadout: equipmentLoadout,
                inventoryItems: inventoryItems,
                onEquip: { equip($0, in: slot) }
            )
        }
        .navigationDestination(item: $selectedAbilityTier) { tier in
            AbilityTierPickerSheet(
                combatant: combatant,
                tier: tier,
                selectedAbilityID: loadout.ability(for: tier)?.id,
                onSelectAbility: select
            )
        }
        .navigationDestination(item: $viewingAbility) { wrapper in
            AbilityDetailView(ability: wrapper.ability)
        }
        .navigationDestination(item: $viewingItem) { item in
            ItemDetailView(item: item)
        }
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: hapticsEnabled
        )
    }

    @ViewBuilder
    private func combatantDetailBody(combatBuild: CombatBuild) -> some View {
        statsSection(combatBuild: combatBuild)

        if let heroOrCompanionTrait {
            traitSection(
                traits: [heroOrCompanionTrait],
                sectionID: AccessibilityID.CombatantDetail.traitSection,
                descriptionID: AccessibilityID.CombatantDetail.traitDescription
            )
        }

        if !enemyTraits.isEmpty {
            traitSection(
                traits: enemyTraits,
                sectionID: AccessibilityID.CombatantDetail.enemyTraitsSection,
                descriptionID: AccessibilityID.CombatantDetail.enemyTraitDescription
            )
        }

        if !activeEffectSummaries.isEmpty {
            activeEffectsSection
        }

        DetailSection("Abilities") {
            AbilitySummaryGrid(
                combatant: combatant,
                progression: progression,
                loadout: $loadout,
                allowsEditing: allowsEditing,
                onSelectTier: allowsEditing ? { selectedAbilityTier = $0 } : nil,
                onViewAbility: allowsEditing ? nil : { viewingAbility = ViewOnlyAbility(ability: $0) }
            )
            .padding(.vertical, TrinketDesign.Metrics.extraSmallSpacing)
        }

        DetailSection("Items") {
            EquipmentSlotSummaryGrid(
                role: combatant.role,
                equipmentLoadout: equipmentLoadout,
                inventoryItems: inventoryItems,
                onSelect: allowsEditing ? { selectedItemSlot = $0 } : nil,
                onViewItem: allowsEditing ? nil : { viewingItem = $0 }
            )
            .padding(.vertical, TrinketDesign.Metrics.extraSmallSpacing)
        }
    }

    private func statsSection(combatBuild: CombatBuild) -> some View {
        DetailSection("Stats", sectionID: AccessibilityID.CombatantDetail.statsSection) {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                statCard {
                    statRow(
                        "Health",
                        value: "\(currentHealth(for: combatBuild))/\(combatBuild.effectiveMaxHealth)",
                        accessibilityIdentifier: AccessibilityID.CombatantDetail.healthStat
                    )
                }

                statCard {
                    if combatant.role != .enemy, combatBuild.effectiveMaxMana > 0 {
                        statRow("Mana", value: "\(combatBuild.effectiveMaxMana) MP")
                    }
                    statRow("Strength", value: "\(combatBuild.combatant.primaryStats.strength)")
                    statRow("Agility", value: "\(combatBuild.combatant.primaryStats.agility)")
                    statRow("Toughness", value: "\(combatBuild.combatant.primaryStats.toughness)")
                    statRow("Intellect", value: "\(combatBuild.combatant.primaryStats.intellect)")
                    statRow("Wisdom", value: "\(combatBuild.combatant.primaryStats.wisdom)")
                }
            }
        }
    }

    private var activeEffectsSection: some View {
        DetailSection("Active Effects") {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                ForEach(activeEffectSummaries) { summary in
                    let parts = activeEffectCardParts(for: summary)
                    DetailTraitRow(title: parts.title, description: parts.description)
                }
            }
        }
    }

    private func traitSection(
        traits: [CombatantTraitDefinition],
        sectionID: String,
        descriptionID: String
    ) -> some View {
        DetailSection("Traits", sectionID: sectionID) {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                ForEach(traits) { trait in
                    DetailTraitRow(
                        title: trait.name,
                        description: detailDescription(trait.description),
                        descriptionAccessibilityID: descriptionID
                    )
                }
            }
        }
    }

    private func currentHealth(for combatBuild: CombatBuild) -> Int {
        battleHealth ?? combatBuild.effectiveMaxHealth
    }

    private func select(_ ability: Ability) {
        loadout = loadout.selecting(ability)
        selectionFeedbackTrigger += 1
        selectedAbilityTier = nil
    }

    private func equip(_ item: InventoryItem, in slot: ItemSlot) {
        var updated = equipmentLoadout
        updated.equip(item, in: slot)
        equipmentLoadout = updated
        playSFX(SFXID.uiEquip, effectsVolume)
        selectionFeedbackTrigger += 1
        Task { @MainActor in
            await Task.yield()
            selectedItemSlot = nil
        }
    }

    private func statRow(_ title: String, value: String, accessibilityIdentifier: String? = nil) -> some View {
        LabeledContent {
            Text(value)
                .trinketTypography(.statValue)
                .foregroundStyle(.secondary)
        } label: {
            Text(title)
                .trinketTypography(.body)
                .foregroundStyle(.primary)
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }

    private func statCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trinketSurface(.secondary)
    }

    private func activeEffectCardParts(for summary: EffectSummary) -> (title: String, description: String) {
        if let separator = summary.text.range(of: ": ") {
            let title = String(summary.text[..<separator.lowerBound])
            let description = String(summary.text[separator.upperBound...])
            return (detailDescription(title), detailDescription(description))
        }
        return (detailDescription(summary.text), detailDescription(summary.keyword.rulesText))
    }

    private func detailDescription(_ text: String) -> String {
        text.hasSuffix(".") ? String(text.dropLast()) : text
    }
}

public extension CombatantDetailPane {
    init(
        snapshot: CombatantCardDetail,
        hidesNavigationBar: Bool = false
    ) {
        self.init(
            combatant: snapshot.combatant,
            progression: snapshot.progression,
            loadout: .constant(snapshot.combatant.abilityLoadout),
            equipmentLoadout: .constant(snapshot.equipmentLoadout),
            inventoryItems: .constant(snapshot.inventoryItems),
            allowsEditing: false,
            hapticsEnabled: false,
            effectsVolume: 0,
            battleHealth: snapshot.health,
            activeEffectSummaries: snapshot.activeEffectSummaries,
            hidesNavigationBar: hidesNavigationBar
        )
    }
}
