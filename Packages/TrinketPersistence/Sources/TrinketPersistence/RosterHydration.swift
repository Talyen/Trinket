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
        from loadouts: [String: AbilityLoadout]
    ) -> [String: AbilityLoadout] {
        var resolved: [String: AbilityLoadout] = [:]
        for (combatantID, loadout) in loadouts {
            guard let combatant = combatantsByID[combatantID] else { continue }
            // Same exact-then-remap rules as wire decode via WireAbilityLoadout.
            resolved[combatantID] = WireAbilityLoadout(loadout).loadout(
                defaults: combatant.abilityLoadout,
                choices: combatant.abilityChoices
            )
        }
        return resolved
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
        _ loadout: EquipmentLoadout,
        inventoryItemIDs: Set<String>,
        combatant: Combatant? = nil,
        inventoryItems: [InventoryItem]? = nil
    ) -> EquipmentLoadout {
        var resolvedItems: [ItemSlot: String] = [:]
        for (slot, itemID) in loadout.itemIDsBySlot {
            guard inventoryItemIDs.contains(itemID) else { continue }
            resolvedItems[slot] = itemID
        }
        var cleaned = EquipmentLoadout(itemIDsBySlot: resolvedItems)
        if let combatant, let inventoryItems {
            cleaned = cleaned.sanitized(for: combatant, inventory: inventoryItems)
        }
        return cleaned
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
        from loadouts: [String: EquipmentLoadout],
        inventoryItemIDs: Set<String>,
        inventoryItems: [InventoryItem]? = nil
    ) -> [String: EquipmentLoadout] {
        var resolved: [String: EquipmentLoadout] = [:]
        for (combatantID, loadout) in loadouts {
            let combatant = combatantsByID[combatantID]
            if inventoryItems != nil, combatant == nil {
                continue
            }
            resolved[combatantID] = resolveEquipmentLoadout(
                loadout,
                inventoryItemIDs: inventoryItemIDs,
                combatant: combatant,
                inventoryItems: inventoryItems
            )
        }
        return enforceUniqueEquippedItems(resolved)
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
        return enforceUniqueEquippedItems(resolved)
    }

    /// One inventory instance may only be equipped on one combatant. First claim
    /// wins in stable combatant-ID order; later duplicates are stripped.
    static func enforceUniqueEquippedItems(
        _ loadouts: [String: EquipmentLoadout]
    ) -> [String: EquipmentLoadout] {
        var claimedItemIDs = Set<String>()
        var unique: [String: EquipmentLoadout] = [:]
        for combatantID in loadouts.keys.sorted() {
            guard let loadout = loadouts[combatantID] else { continue }
            var cleaned = EquipmentLoadout()
            for slot in ItemSlot.allCases {
                guard let itemID = loadout.itemID(for: slot) else { continue }
                guard claimedItemIDs.insert(itemID).inserted else { continue }
                cleaned.itemIDsBySlot[slot] = itemID
            }
            unique[combatantID] = cleaned
        }
        return unique
    }
}
