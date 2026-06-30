import Foundation

enum PlayerSaveSanitizer {
    static func sanitize(_ save: PlayerSave) -> PlayerSave {
        var sanitized = save
        sanitized.inventory = SavedInventoryState(sanitizeInventory(save.inventory.inventory()))
        sanitized.roster = sanitizeRoster(
            sanitized.roster,
            inventoryItemIDs: inventoryItemIDs(from: sanitized.inventory)
        )
        return sanitized
    }

    static func sanitizeInventory(_ inventory: PlayerInventoryState) -> PlayerInventoryState {
        var seenIDs = Set<String>()
        let uniqueItems = inventory.items.filter { item in
            guard !seenIDs.contains(item.id) else { return false }
            seenIDs.insert(item.id)
            return true
        }
        return PlayerInventoryState(items: uniqueItems)
    }

    static func sanitizeRoster(
        _ roster: SavedRosterState,
        inventoryItemIDs: Set<String>
    ) -> SavedRosterState {
        let validHeroIDs = Set(GameContent.heroes.map(\.id))
        let validPetIDs = Set(GameContent.pets.map(\.id))
        let combatantsByID = Dictionary(
            uniqueKeysWithValues: (GameContent.heroes + GameContent.pets).map { ($0.id, $0) }
        )

        var sanitized = roster
        sanitized.unlockedHeroIDs = roster.unlockedHeroIDs.filter { validHeroIDs.contains($0) }
        sanitized.unlockedPetIDs = roster.unlockedPetIDs.filter { validPetIDs.contains($0) }

        if sanitized.unlockedHeroIDs.isEmpty {
            sanitized.unlockedHeroIDs = [PlayerRosterState.starterHeroID]
        }
        if sanitized.unlockedPetIDs.isEmpty {
            sanitized.unlockedPetIDs = [PlayerRosterState.starterPetID]
        }

        let unlockedHeroIDs = Set(sanitized.unlockedHeroIDs)
        let unlockedPetIDs = Set(sanitized.unlockedPetIDs)

        if !unlockedHeroIDs.contains(sanitized.activeHeroID) {
            sanitized.activeHeroID = sanitized.unlockedHeroIDs.first ?? PlayerRosterState.starterHeroID
        }
        if !unlockedPetIDs.contains(sanitized.activePetID) {
            sanitized.activePetID = sanitized.unlockedPetIDs.first ?? PlayerRosterState.starterPetID
        }

        sanitized.equipmentLoadouts = roster.equipmentLoadouts.mapValues { savedLoadout in
            SavedEquipmentLoadout(savedLoadout.loadout(inventoryItemIDs: inventoryItemIDs))
        }

        sanitized.abilityLoadouts = roster.abilityLoadouts
        for combatantID in Array(sanitized.abilityLoadouts.keys) {
            guard let combatant = combatantsByID[combatantID] else {
                sanitized.abilityLoadouts.removeValue(forKey: combatantID)
                continue
            }
            let resolved = sanitized.abilityLoadouts[combatantID]?.loadout(
                defaults: combatant.abilityLoadout,
                choices: combatant.abilityChoices
            ) ?? combatant.abilityLoadout
            sanitized.abilityLoadouts[combatantID] = SavedAbilityLoadout(resolved)
        }

        return sanitized
    }

    private static func inventoryItemIDs(from inventory: SavedInventoryState) -> Set<String> {
        Set(inventory.items.map(\.id))
    }
}
