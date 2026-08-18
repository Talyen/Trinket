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

    /// Loadout picker navigation state is owned here at the pane level so the picker
    /// destinations are at the root of whatever NavigationStack presents this view.
    /// Each picker owns its detail destination so Back returns to that picker grid.
    @State private var selectedItemSlot: ItemSlot?
    @State private var selectedAbilityTier: AbilityTier?
    @State private var viewingAbility: ViewOnlyAbility?
    @State private var viewingItem: InventoryItem?
    @State private var selectedTalentTree: TalentTree?
    @State private var selectionFeedbackTrigger = 0
    @State private var cachedCombatBuild: CombatBuild?

    /// Distinct from `Ability` so view-only and loadout destinations do not collide.
    private struct ViewOnlyAbility: Hashable, Identifiable {
        let ability: Ability

        var id: String {
            ability.id
        }
    }

    private struct CombatBuildInputs: Equatable {
        let combatantID: String
        let loadout: AbilityLoadout
        let equipmentLoadout: EquipmentLoadout
        let inventoryItems: [InventoryItem]
        let unlockedTalents: Set<String>
    }

    private var combatBuildInputs: CombatBuildInputs {
        CombatBuildInputs(
            combatantID: combatant.id,
            loadout: loadout,
            equipmentLoadout: equipmentLoadout,
            inventoryItems: inventoryItems,
            unlockedTalents: unlockedTalents
        )
    }

    private func makeCombatBuild() -> CombatBuild {
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
        let combatBuild = cachedCombatBuild ?? makeCombatBuild()

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
        .onAppear {
            if cachedCombatBuild == nil {
                cachedCombatBuild = makeCombatBuild()
            }
        }
        .onChange(of: combatBuildInputs) {
            cachedCombatBuild = makeCombatBuild()
        }
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

        if !activeModifierSummaries.isEmpty {
            activeModifiersSection
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

    private var activeModifierSummaries: [EffectSummary] {
        guard combatant.role != .enemy else { return [] }
        let config = CombatantTalentCatalog.config(for: combatant.id)
        let allNodes = config.trees.flatMap(\.nodes)
        let nodeMap = Dictionary(uniqueKeysWithValues: allNodes.map { ($0.id, $0) })
        return unlockedTalents.sorted().compactMap { nodeID in
            guard let effect = CombatantTalentCatalog.effect(for: nodeID) else { return nil }
            let keyword = nodeMap[nodeID]?.keyword ?? .physical
            return EffectSummary(keyword: keyword, text: "\(effect.name): \(effect.description)")
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

    private var activeModifiersSection: some View {
        DetailSection("Active Talents") {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                ForEach(activeModifierSummaries) { summary in
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
        let style = tree.keyword.visualStyle
        let artReference = tree.keyword.artReference
        let hasUnallocatedPoints = availablePoints > 0
        let unlockedCount = tree.nodes.count(where: { unlockedTalents.contains($0.id) })

        return Button {
            selectedTalentTree = tree
        } label: {
            ProductCardShell(
                isSelected: false,
                showsLabel: true,
                reservesLabelSpace: true,
                shineKeywords: hasUnallocatedPoints ? [tree.keyword] : nil,
                shineLineWidth: 2,
                art: {
                    if let artReference {
                        Image.preparedAsset(artReference, displaySize: .compact)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .decorativePreparedArtwork()
                    } else {
                        ZStack {
                            TrinketDesign.cardShape
                                .fill(style.color.opacity(0.18))
                            Image(systemName: style.symbolName)
                                .font(.system(size: TrinketDesign.Metrics.cardPlaceholderIconPointSize, weight: .semibold))
                                .foregroundStyle(style.color)
                        }
                    }
                },
                label: {
                    VStack(spacing: 2) {
                        Text(tree.name)
                            .trinketTypography(.cardLabel)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Text("\(unlockedCount)/\(tree.nodes.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.CombatantDetail.talentsNode(id: tree.keyword.rawValue))
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
