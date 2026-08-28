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
    @Binding var unlockedTalents: Set<String>
    let allowsEditing: Bool
    let hapticsEnabled: Bool
    let effectsVolume: Double
    var battleHealth: Int?
    var battleMana: Int?
    var activeEffectSummaries: [EffectSummary] = []
    var labyrinthModifiers: [LabyrinthModifierDefinition] = []
    var hidesNavigationBar = false
    var onUnlockTalent: ((TalentNode, TalentTree) -> Void)?
    var onResetTalents: (() -> Void)?

    @State private var selectedItemSlot: ItemSlot?
    @State private var selectedAbilityTier: AbilityTier?
    @State private var viewingAbility: ViewOnlyAbility?
    @State private var viewingItem: InventoryItem?
    @State private var selectedTalentTree: TalentTree?
    @State private var selectionFeedbackTrigger = 0

    private struct ViewOnlyAbility: Hashable, Identifiable {
        let ability: Ability

        var id: String {
            ability.id
        }
    }

    private var combatBuild: CombatBuild {
        CombatBuildResolver.build(
            combatant: combatant,
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryItems,
            unlockedTalents: unlockedTalents
        )
    }

    private var enemyTraits: [CombatantTraitDefinition] {
        guard combatant.role == .enemy,
              let enemy = GameContent.enemy(matching: combatant.id)
        else { return [] }
        return GameContent.trait(for: enemy).map { [$0] } ?? []
    }

    public var body: some View {
        let combatBuild = combatBuild

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
        .navigationDestination(item: $selectedTalentTree) { tree in
            CombatantTalentsView(
                tree: tree,
                progression: progression,
                unlockedTalents: $unlockedTalents,
                allowsEditing: allowsEditing,
                onUnlockTalent: { node, tree in
                    onUnlockTalent?(node, tree)
                },
                onResetTalents: {
                    onResetTalents?()
                }
            )
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

        if !enemyTraits.isEmpty {
            traitSection(
                traits: enemyTraits,
                sectionID: AccessibilityID.CombatantDetail.enemyTraitsSection,
                descriptionID: AccessibilityID.CombatantDetail.enemyTraitDescription
            )
        }

        if !labyrinthModifiers.isEmpty {
            labyrinthModifiersSection
        }

        if !activeEffectSummaries.isEmpty {
            activeEffectsSection
        }

        if combatant.role != .enemy {
            talentsSection
        }

        DetailSection("Abilities") {
            AbilitySummaryGrid(
                combatant: combatant,
                loadout: $loadout,
                allowsEditing: allowsEditing,
                onSelectTier: allowsEditing ? { selectedAbilityTier = $0 } : nil,
                onViewAbility: allowsEditing ? nil : { viewingAbility = ViewOnlyAbility(ability: $0) },
                onInspectAbility: { viewingAbility = ViewOnlyAbility(ability: $0) }
            )
            .padding(.vertical, TrinketDesign.Metrics.extraSmallSpacing)
        }

        if combatant.role != .enemy {
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
                    if combatant.role != .enemy, combatBuild.effectiveMaxMana > 0 {
                        statRow(
                            "Mana",
                            value: "\(currentMana(for: combatBuild))/\(combatBuild.effectiveMaxMana)"
                        )
                    }
                }

                statCard {
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
                    DetailTraitRow(
                        title: parts.title,
                        description: parts.description,
                        leadingIconKeyword: summary.keyword
                    )
                }
            }
        }
    }

    private var labyrinthModifiersSection: some View {
        DetailSection(
            "Labyrinth",
            sectionID: AccessibilityID.CombatantDetail.labyrinthModifiersSection
        ) {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                ForEach(labyrinthModifiers) { modifier in
                    DetailTraitRow(
                        title: modifier.title,
                        description: detailDescription(modifier.effect.description),
                        descriptionAccessibilityID: AccessibilityID.CombatantDetail.labyrinthModifierDescription
                    )
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

    private func currentMana(for combatBuild: CombatBuild) -> Int {
        battleMana ?? combatBuild.effectiveMaxMana
    }

    private func select(_ ability: Ability) {
        loadout = loadout.selecting(ability)
        selectionFeedbackTrigger += 1
        selectedAbilityTier = nil
    }

    private func equip(_ item: InventoryItem, in slot: ItemSlot) {
        var updated = equipmentLoadout
        updated.equip(item, in: slot, inventory: inventoryItems)
        withAnimation(TrinketMotion.Interaction.selection) {
            equipmentLoadout = updated
        }
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
                .contentTransition(.numericText())
                .animation(TrinketMotion.Interaction.selection, value: value)
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

private extension CombatantDetailPane {
    var talentsSection: some View {
        let config = CombatantTalentCatalog.config(for: combatant.id)
        let available = progression.availableTalentPoints(unlockedCount: unlockedTalents.count)

        return DetailSection("Talents", sectionID: AccessibilityID.CombatantDetail.talentsSection) {
            HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                ForEach(config.trees) { tree in
                    talentTreeCard(tree: tree, availablePoints: available)
                }
            }
            .padding(.vertical, TrinketDesign.Metrics.extraSmallSpacing)
        }
    }

    func talentTreeCard(tree: TalentTree, availablePoints: Int) -> some View {
        let hasUnallocatedPoints = availablePoints > 0
        let unlockedCount = tree.nodes.count(where: { unlockedTalents.contains($0.id) })

        return Button {
            selectedTalentTree = tree
        } label: {
            TalentTreeCard(
                tree: tree,
                caption: "\(unlockedCount)/\(tree.nodes.count)",
                showsShine: hasUnallocatedPoints,
                accessibilityID: AccessibilityID.CombatantDetail.talentsNode(id: tree.keyword.rawValue)
            )
        }
        .trinketQuietTapButtonStyle()
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
            unlockedTalents: .constant(snapshot.unlockedTalents),
            allowsEditing: false,
            hapticsEnabled: false,
            effectsVolume: 0,
            battleHealth: snapshot.health,
            battleMana: snapshot.mana,
            activeEffectSummaries: snapshot.activeEffectSummaries,
            labyrinthModifiers: snapshot.labyrinthModifiers,
            hidesNavigationBar: hidesNavigationBar
        )
    }
}
