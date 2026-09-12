import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

public struct CombatantDetailPane: View {
    @Environment(\.playSFX) private var playSFX

    let combatant: Combatant
    let progression: CombatantProgression
    let loadout: AbilityLoadout
    let equipmentLoadout: EquipmentLoadout
    let inventoryItems: [InventoryItem]
    let unlockedTalents: Set<String>
    let allowsEditing: Bool
    let hapticsEnabled: Bool
    let effectsVolume: Double
    var battleHealth: Int?
    var battleMana: Int?
    var activeEffectSummaries: [EffectSummary] = []
    var labyrinthModifiers: [LabyrinthModifierDefinition] = []
    var hidesNavigationBar = false
    var onEdit: ((CombatantDetailEdit) -> Bool)?
    var onUnlockTalent: ((TalentNode, TalentTree) -> TalentUnlockResult)?

    @State private var selectedItemSlot: ItemSlot?
    @State private var requestedItemSlot: ItemSlot?
    @State private var pickerItems = ItemPickerItems()
    @State private var pickerArtworkLease: ItemPickerArtworkLease?
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
                initialItems: pickerItems,
                onEquip: { equip($0, in: slot) },
                onUnequip: { unequip(slot) },
            )
        }
        .task(id: requestedItemSlot) {
            guard let slot = requestedItemSlot else { return }
            var items = ItemPickerItems()
            items.update(inventory: inventoryItems, loadout: equipmentLoadout, slot: slot)
            let lease = await ItemPickerArtworkLease(items: items.eligible)
            guard !Task.isCancelled else { return }
            pickerItems = items
            pickerArtworkLease = lease
            selectedItemSlot = slot
            requestedItemSlot = nil
        }
        .onChange(of: selectedItemSlot) { _, slot in
            if slot == nil {
                requestedItemSlot = nil
                pickerArtworkLease = nil
                pickerItems = ItemPickerItems()
            }
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
                unlockedTalents: unlockedTalents,
                allowsEditing: allowsEditing,
                hapticsEnabled: hapticsEnabled,
                onUnlockTalent: { node, tree in
                    onUnlockTalent?(node, tree) ?? .unavailable
                },
                onResetTalents: { onEdit?(.resetTalents) ?? false },
            )
        }
        .onChange(of: selectedTalentTree?.id) { oldValue, newValue in
            guard oldValue != newValue, newValue != nil else { return }
            selectionFeedbackTrigger &+= 1
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
            if selectedItemSlot == nil {
                requestedItemSlot = nil
            }
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
        if let config = CombatantTalentCatalog.configIfAvailable(for: combatant.id) {
            for tree in config.trees {
                if let ref = tree.keyword.artReference {
                    names.append(ref.thumbnailImageName ?? ref.imageName)
                }
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
        CombatantVitalBarsView(
            combatBuild: combatBuild,
            combatantRole: combatant.role,
            battleHealth: battleHealth,
            battleMana: battleMana,
        )
        .equatable()

        if !enemyTraits.isEmpty {
            CombatantTraitsSection(
                traits: enemyTraits,
                sectionID: AccessibilityID.CombatantDetail.enemyTraitsSection,
                descriptionID: AccessibilityID.CombatantDetail.enemyTraitDescription,
            )
            .equatable()
        }

        if !labyrinthModifiers.isEmpty {
            CombatantLabyrinthSection(labyrinthModifiers: labyrinthModifiers)
                .equatable()
        }

        if !activeEffectSummaries.isEmpty {
            CombatantActiveEffectsSection(summaries: activeEffectSummaries)
                .equatable()
        }

        DetailSection("Abilities") {
            AbilitySummaryGrid(
                combatant: combatant,
                loadout: loadout,
                allowsEditing: allowsEditing,
                onSelectTier: allowsEditing ? { selectedAbilityTier = $0 } : nil,
                onViewAbility: allowsEditing ? nil : { viewingAbility = $0 },
                onInspectAbility: { viewingAbility = $0 },
            )
            .padding(.vertical, TrinketDesign.Spacing.extraSmall)
        }

        if combatant.role != .enemy {
            CombatantTalentsSection(
                combatantID: combatant.id,
                progression: progression,
                unlockedTalents: unlockedTalents,
                onSelectTree: { selectedTalentTree = $0 },
            )
        }

        if combatant.role != .enemy {
            DetailSection("Items") {
                EquipmentSlotSummaryGrid(
                    role: combatant.role,
                    equipmentLoadout: equipmentLoadout,
                    inventoryItems: inventoryItems,
                    onSelect: allowsEditing ? { requestedItemSlot = $0 } : nil,
                    onViewItem: allowsEditing ? nil : { viewingItem = $0 },
                )
                .padding(.vertical, TrinketDesign.Spacing.extraSmall)
            }
        }
    }

    private func select(_ ability: Ability) -> Bool {
        guard onEdit?(.selectAbility(ability)) == true else { return false }
        selectionFeedbackTrigger += 1
        selectedAbilityTier = nil
        return true
    }

    private func equip(_ item: InventoryItem, in slot: ItemSlot) -> Bool {
        let saved = withAnimation(TrinketMotion.Interaction.selection) {
            onEdit?(.equipItem(item, slot)) == true
        }
        guard saved else { return false }
        playSFX(SFXID.uiEquip, effectsVolume)
        selectionFeedbackTrigger += 1
        Task { @MainActor in
            await Task.yield()
            selectedItemSlot = nil
        }
        return true
    }

    private func unequip(_ slot: ItemSlot) -> Bool {
        guard onEdit?(.unequipItem(slot)) == true else { return false }
        selectionFeedbackTrigger += 1
        selectedItemSlot = nil
        return true
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
            loadout: snapshot.combatant.abilityLoadout,
            equipmentLoadout: snapshot.equipmentLoadout,
            inventoryItems: snapshot.inventoryItems,
            unlockedTalents: snapshot.unlockedTalents,
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
