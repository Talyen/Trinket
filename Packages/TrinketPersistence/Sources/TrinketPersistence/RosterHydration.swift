import Foundation
import TrinketContent
import TrinketCore

enum RosterHydration {
    static let combatantsByID = Dictionary(
        uniqueKeysWithValues: (GameContent.heroes + GameContent.companions).map { ($0.id, $0) }
    )

    static func resolveActiveSelection(
        activeHeroID: String,
        activeCompanionID: String,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>
    ) -> (activeHeroID: String, activeCompanionID: String) {
        let resolvedHeroID = unlockedHeroIDs.contains(activeHeroID)
            ? activeHeroID
            : (unlockedHeroIDs.first ?? PlayerRosterState.starterHeroID)
        let resolvedCompanionID = unlockedCompanionIDs.contains(activeCompanionID)
            ? activeCompanionID
            : (unlockedCompanionIDs.first ?? PlayerRosterState.starterCompanionID)
        return (resolvedHeroID, resolvedCompanionID)
    }

    static func resolveAbilityLoadouts(
        from wireLoadouts: [String: WireAbilityLoadout]
    ) -> [String: AbilityLoadout] {
        var resolved: [String: AbilityLoadout] = [:]
        for (combatantID, wireLoadout) in wireLoadouts {
            guard let combatant = combatantsByID[combatantID] else { continue }
            resolved[combatantID] = wireLoadout.loadout(
                defaults: combatant.abilityLoadout,
                choices: combatant.abilityChoices
            )
        }
        return resolved
    }

    static func resolveEquipmentLoadout(
        _ wireLoadout: WireEquipmentLoadout,
        inventoryItemIDs: Set<String>,
        combatant: Combatant? = nil,
        inventoryItems: [InventoryItem]? = nil
    ) -> EquipmentLoadout {
        var loadout = wireLoadout.loadout(inventoryItemIDs: inventoryItemIDs)
        if let combatant, let inventoryItems {
            loadout = loadout.sanitized(for: combatant, inventory: inventoryItems)
        }
        return loadout
    }

    static func resolveEquipmentLoadouts(
        from wireLoadouts: [String: WireEquipmentLoadout],
        inventoryItemIDs: Set<String>,
        inventoryItems: [InventoryItem]? = nil
    ) -> [String: EquipmentLoadout] {
        var resolved: [String: EquipmentLoadout] = [:]
        for (combatantID, wireLoadout) in wireLoadouts {
            let combatant = combatantsByID[combatantID]
            if inventoryItems != nil, combatant == nil {
                continue
            }
            resolved[combatantID] = resolveEquipmentLoadout(
                wireLoadout,
                inventoryItemIDs: inventoryItemIDs,
                combatant: combatant,
                inventoryItems: inventoryItems
            )
        }
        return resolved
    }
}
