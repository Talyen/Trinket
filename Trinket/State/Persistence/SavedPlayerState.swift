import Foundation

struct SavedAbilityLoadout: Codable, Equatable {
    var basicID: String?
    var skillID: String?
    var ultimateID: String?

    init(_ loadout: AbilityLoadout) {
        basicID = loadout.basic?.id
        skillID = loadout.skill?.id
        ultimateID = loadout.ultimate?.id
    }

    func loadout(defaults: AbilityLoadout, choices: AbilityChoices) -> AbilityLoadout {
        func resolved(_ id: String?, tier: AbilityTier, fallback: Ability?) -> Ability? {
            guard let id else { return fallback }
            return choices.abilities(for: tier).first { $0.id == id } ?? fallback
        }

        return AbilityLoadout(
            basic: resolved(basicID, tier: .basic, fallback: defaults.basic),
            skill: resolved(skillID, tier: .skill, fallback: defaults.skill),
            ultimate: resolved(ultimateID, tier: .ultimate, fallback: defaults.ultimate)
        )
    }
}

struct SavedEquipmentLoadout: Codable, Equatable {
    var itemIDsBySlot: [String: String]

    init(_ loadout: EquipmentLoadout) {
        itemIDsBySlot = Dictionary(uniqueKeysWithValues: loadout.itemIDsBySlot.map { ($0.key.rawValue, $0.value) })
    }

    func loadout(inventoryItemIDs: Set<String>) -> EquipmentLoadout {
        var resolved: [ItemSlot: String] = [:]
        for (slotRawValue, itemID) in itemIDsBySlot {
            guard let slot = ItemSlot(rawValue: slotRawValue), inventoryItemIDs.contains(itemID) else { continue }
            resolved[slot] = itemID
        }
        return EquipmentLoadout(itemIDsBySlot: resolved)
    }
}

struct SavedItemAffix: Codable, Equatable {
    var id: String
    var title: String
    var description: String
    var keywordRawValues: [String]
    var effect: SavedEffect?

    init(_ affix: ItemAffix) {
        id = affix.id
        title = affix.title
        description = affix.description
        keywordRawValues = affix.keywords.map(\.rawValue).sorted()
        effect = affix.effect.map(SavedEffect.init)
    }

    func affix() -> ItemAffix? {
        let keywords = Set(keywordRawValues.compactMap { Keyword(rawValue: $0) })
        return ItemAffix(
            id: id,
            title: title,
            description: description,
            keywords: keywords,
            effect: effect?.effect()
        )
    }
}

struct SavedInventoryItem: Codable, Equatable {
    var id: String
    var templateID: String
    var baseTypeID: String
    var rarity: Rarity
    var displayName: String
    var affixes: [SavedItemAffix]

    init(_ item: InventoryItem) {
        id = item.id
        templateID = item.templateID
        baseTypeID = item.baseType.id
        rarity = item.rarity
        displayName = item.displayName
        affixes = item.affixes.map(SavedItemAffix.init)
    }

    func item() -> InventoryItem? {
        guard let baseType = GameContent.itemBaseTypes.first(where: { $0.id == baseTypeID }) else { return nil }
        let resolvedAffixes = affixes.compactMap { $0.affix() }
        return InventoryItem(
            id: id,
            templateID: templateID,
            baseType: baseType,
            rarity: rarity,
            displayName: displayName,
            affixes: resolvedAffixes
        )
    }
}

struct SavedRosterState: Codable, Equatable {
    var activeHeroID: String
    var activePetID: String
    var abilityLoadouts: [String: SavedAbilityLoadout]
    var progressions: [String: CombatantProgression]
    var equipmentLoadouts: [String: SavedEquipmentLoadout]
    var gold: Int

    init(_ roster: PlayerRosterState) {
        activeHeroID = roster.activeHeroID
        activePetID = roster.activePetID
        abilityLoadouts = roster.abilityLoadouts.mapValues(SavedAbilityLoadout.init)
        progressions = roster.progressions
        equipmentLoadouts = roster.equipmentLoadouts.mapValues(SavedEquipmentLoadout.init)
        gold = roster.gold
    }

    func roster(inventoryItemIDs: Set<String>) -> PlayerRosterState {
        let combatantsByID = Dictionary(
            uniqueKeysWithValues: (GameContent.heroes + GameContent.pets).map { ($0.id, $0) }
        )

        var resolvedAbilityLoadouts: [String: AbilityLoadout] = [:]
        for (combatantID, savedLoadout) in abilityLoadouts {
            guard let combatant = combatantsByID[combatantID] else { continue }
            resolvedAbilityLoadouts[combatantID] = savedLoadout.loadout(
                defaults: combatant.abilityLoadout,
                choices: combatant.abilityChoices
            )
        }

        var resolvedEquipmentLoadouts: [String: EquipmentLoadout] = [:]
        for (combatantID, savedLoadout) in equipmentLoadouts {
            resolvedEquipmentLoadouts[combatantID] = savedLoadout.loadout(inventoryItemIDs: inventoryItemIDs)
        }

        let heroIDs = Set(GameContent.heroes.map(\.id))
        let petIDs = Set(GameContent.pets.map(\.id))
        let resolvedHeroID = heroIDs.contains(activeHeroID) ? activeHeroID : (GameContent.heroes.first?.id ?? "")
        let resolvedPetID = petIDs.contains(activePetID) ? activePetID : (GameContent.pets.first?.id ?? "")

        return PlayerRosterState(
            activeHeroID: resolvedHeroID,
            activePetID: resolvedPetID,
            abilityLoadouts: resolvedAbilityLoadouts,
            progressions: progressions,
            equipmentLoadouts: resolvedEquipmentLoadouts,
            gold: gold
        )
    }
}

struct SavedInventoryState: Codable, Equatable {
    var items: [SavedInventoryItem]

    init(_ inventory: PlayerInventoryState) {
        items = inventory.items.map(SavedInventoryItem.init)
    }

    func inventory() -> PlayerInventoryState {
        PlayerInventoryState(items: items.compactMap { $0.item() })
    }
}
