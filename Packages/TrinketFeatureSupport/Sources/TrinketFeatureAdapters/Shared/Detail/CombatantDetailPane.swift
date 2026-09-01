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
    @State private var viewingAbility: Ability?
    @State private var viewingItem: InventoryItem?
    @State private var selectedTalentTree: TalentTree?
    @State private var selectionFeedbackTrigger = 0
    @State private var pinnedDetailArtwork: [String] = []

    private static let pinnedInventoryArtworkLimit = 12

    private var combatBuild: CombatBuild {
        CombatBuildResolver.build(
            combatant: combatant,
            equipmentLoadout: equipmentLoadout,
            inventory: inventoryItems,
            unlockedTalents: unlockedTalents,
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
            hidesNavigationBar: hidesNavigationBar,
        ) { baseHeight in
            DetailHeroHeader(
                eyebrow: combatant.role.rawValue.uppercased(),
                title: combatant.name,
                baseHeight: baseHeight,
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
                onEquip: { equip($0, in: slot) },
            )
        }
        .navigationDestination(item: $selectedAbilityTier) { tier in
            AbilityTierPickerSheet(
                combatant: combatant,
                tier: tier,
                selectedAbilityID: loadout.ability(for: tier)?.id,
                onSelectAbility: select,
            )
        }
        .navigationDestination(item: $viewingAbility) { ability in
            AbilityDetailView(ability: ability)
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
                },
            )
        }
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: hapticsEnabled,
        )
        .task(id: detailArtworkPinKey) {
            await refreshDetailArtworkPins()
        }
        .onDisappear {
            PreparedArtworkCache.shared.releasePins(names: pinnedDetailArtwork)
            pinnedDetailArtwork = []
        }
    }

    private var detailArtworkPinKey: [String] {
        Set(detailArtworkNames()).sorted()
    }

    private func detailArtworkNames() -> [String] {
        var names: [String] = []
        if let fullName = combatant.artReference?.imageName {
            names.append(fullName)
        }
        if let thumb = combatant.artReference?.thumbnailImageName {
            names.append(thumb)
        }
        let configured = GameContent.combatant(matching: combatant.id) ?? combatant
        for ability in configured.abilities {
            if let ref = ability.artReference {
                names.append(ref.thumbnailImageName ?? ref.imageName)
            }
        }
        for tier in AbilityTier.allCases {
            if let ability = loadout.ability(for: tier), let ref = ability.artReference {
                names.append(ref.thumbnailImageName ?? ref.imageName)
            }
        }
        for tree in CombatantTalentCatalog.config(for: combatant.id).trees {
            if let ref = tree.keyword.artReference {
                names.append(ref.thumbnailImageName ?? ref.imageName)
            }
        }
        for itemID in equipmentLoadout.itemIDsBySlot.values {
            if let item = inventoryItems.first(where: { $0.id == itemID }),
               let ref = item.artReference {
                names.append(ref.thumbnailImageName ?? ref.imageName)
            }
        }
        for item in inventoryItems.prefix(Self.pinnedInventoryArtworkLimit) {
            if let ref = item.artReference {
                names.append(ref.thumbnailImageName ?? ref.imageName)
            }
        }
        return names
    }

    private func refreshDetailArtworkPins() async {
        let next = Set(detailArtworkNames()).sorted()
        let previous = Set(pinnedDetailArtwork)
        let added = Set(next).subtracting(previous)
        let removed = previous.subtracting(next)
        if !added.isEmpty {
            let addedNames = Array(added)
            await PreparedArtworkCache.shared.prepareAndPin(names: addedNames)
            guard !Task.isCancelled else {
                PreparedArtworkCache.shared.releasePins(names: addedNames)
                return
            }
        }
        guard !Task.isCancelled else { return }
        if !removed.isEmpty {
            PreparedArtworkCache.shared.releasePins(names: Array(removed))
        }
        pinnedDetailArtwork = next
    }

    @ViewBuilder
    private func combatantDetailBody(combatBuild: CombatBuild) -> some View {
        CombatantStatsSection(
            combatBuild: combatBuild,
            combatantRole: combatant.role,
            battleHealth: battleHealth,
            battleMana: battleMana,
        )

        if !enemyTraits.isEmpty {
            CombatantTraitsSection(
                traits: enemyTraits,
                sectionID: AccessibilityID.CombatantDetail.enemyTraitsSection,
                descriptionID: AccessibilityID.CombatantDetail.enemyTraitDescription,
            )
        }

        if !labyrinthModifiers.isEmpty {
            CombatantLabyrinthSection(labyrinthModifiers: labyrinthModifiers)
        }

        if !activeEffectSummaries.isEmpty {
            CombatantActiveEffectsSection(summaries: activeEffectSummaries)
        }

        if combatant.role != .enemy {
            CombatantTalentsSection(
                combatantID: combatant.id,
                progression: progression,
                unlockedTalents: unlockedTalents,
                onSelectTree: { selectedTalentTree = $0 },
            )
        }

        DetailSection("Abilities") {
            AbilitySummaryGrid(
                combatant: combatant,
                loadout: $loadout,
                allowsEditing: allowsEditing,
                onSelectTier: allowsEditing ? { selectedAbilityTier = $0 } : nil,
                onViewAbility: allowsEditing ? nil : { viewingAbility = $0 },
                onInspectAbility: { viewingAbility = $0 },
            )
            .padding(.vertical, TrinketDesign.Spacing.extraSmall)
        }

        if combatant.role != .enemy {
            DetailSection("Items") {
                EquipmentSlotSummaryGrid(
                    role: combatant.role,
                    equipmentLoadout: equipmentLoadout,
                    inventoryItems: inventoryItems,
                    onSelect: allowsEditing ? { selectedItemSlot = $0 } : nil,
                    onViewItem: allowsEditing ? nil : { viewingItem = $0 },
                )
                .padding(.vertical, TrinketDesign.Spacing.extraSmall)
            }
        }
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
}

public extension CombatantDetailPane {
    init(
        snapshot: CombatantCardDetail,
        hidesNavigationBar: Bool = false,
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
            hidesNavigationBar: hidesNavigationBar,
        )
    }
}
