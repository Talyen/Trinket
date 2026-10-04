import Foundation
import TrinketContent
import TrinketCore

enum RosterHydration {
    static func resolveActiveSelection(
        activeHeroID: String,
        activeCompanionID: String,
        unlockedHeroIDs: Set<String>,
        unlockedCompanionIDs: Set<String>,
    ) -> (activeHeroID: String, activeCompanionID: String) {
        let resolvedHeroID = unlockedHeroIDs.contains(activeHeroID)
            ? activeHeroID
            : (lowestCatalogOrderedID(from: unlockedHeroIDs, in: GameContent.heroes)
                ?? PlayerRosterState.starterHeroID)
        let resolvedCompanionID = unlockedCompanionIDs.contains(activeCompanionID)
            ? activeCompanionID
            : (lowestCatalogOrderedID(from: unlockedCompanionIDs, in: GameContent.companions)
                ?? PlayerRosterState.starterCompanionID)
        return (resolvedHeroID, resolvedCompanionID)
    }

    private static func lowestCatalogOrderedID(
        from unlockedIDs: Set<String>,
        in catalog: [Combatant],
    ) -> String? {
        catalog.first { unlockedIDs.contains($0.id) }?.id
    }

    /// Sanitization fills missing choices; raw model reads preserve empty tiers.
    static func resolveAbilityLoadouts(
        from loadouts: [String: AbilityLoadout],
    ) -> [String: AbilityLoadout] {
        resolveAbilities(loadouts.mapValues {
            AbilityLoadoutIDs(basicID: $0.basic?.id, skillID: $0.skill?.id, ultimateID: $0.ultimate?.id)
        }, fallbackToDefaults: true)
    }

    static func rawAbilityLoadouts(
        from ids: [String: AbilityLoadoutIDs],
    ) -> [String: AbilityLoadout] {
        resolveAbilities(ids, fallbackToDefaults: false)
    }

    private static func resolveAbilities(
        _ loadouts: [String: AbilityLoadoutIDs],
        fallbackToDefaults: Bool,
    ) -> [String: AbilityLoadout] {
        var resolved: [String: AbilityLoadout] = [:]
        for (combatantID, ids) in loadouts {
            guard let combatant = GameContent.combatant(matching: combatantID) else { continue }
            let defaults = fallbackToDefaults ? combatant.abilityLoadout : nil
            func resolve(_ id: String?, tier: AbilityTier) -> Ability? {
                let fallback = defaults?.ability(for: tier)
                guard let id else { return fallback }
                // Preserve Bandit's Arrow saves after Bounty Shot took over its behavior.
                let canonicalID = id == "sap-arrow" ? "bounty-shot" : id
                return combatant.abilityChoices.abilities(for: tier).first { $0.id == canonicalID } ?? fallback
            }
            resolved[combatantID] = AbilityLoadout(
                basic: resolve(ids.basicID, tier: .basic),
                skill: resolve(ids.skillID, tier: .skill),
                ultimate: resolve(ids.ultimateID, tier: .ultimate),
            )
        }
        return resolved
    }

    struct AbilityLoadoutIDs: Codable, Equatable, Sendable {
        var basicID: String?
        var skillID: String?
        var ultimateID: String?
    }

    static func resolveEquipmentLoadouts(
        from loadouts: [String: EquipmentLoadout],
        inventoryItemIDs: Set<String>,
        inventoryItems: [InventoryItem]? = nil,
    ) -> [String: EquipmentLoadout] {
        guard !loadouts.isEmpty else { return [:] }
        // Narrow the inventory once for the whole roster, rather than scanning every stored item per combatant.
        let equippedInventory = inventoryItems.map { items in
            let equippedIDs = loadouts.values.reduce(into: Set<String>()) {
                $0.formUnion($1.itemIDsBySlot.values)
            }
            return items.filter { equippedIDs.contains($0.id) }
        }
        var resolved: [String: EquipmentLoadout] = [:]
        for (combatantID, loadout) in loadouts {
            let combatant = GameContent.combatant(matching: combatantID)
            // Unknown-combatant drop is active only when inventory items are
            // supplied (sanitizer path). Model/cloud read paths build
            // equipment directly from stored rows and leave dangling refs for
            // sanitize to strip, so a raw round trip never loses data here.
            if equippedInventory != nil, combatant == nil {
                continue
            }
            var cleaned = EquipmentLoadout(itemIDsBySlot: loadout.itemIDsBySlot.filter { inventoryItemIDs.contains($0.value) })
            if let combatant, let equippedInventory {
                cleaned = cleaned.sanitized(for: combatant, inventory: equippedInventory)
            }
            resolved[combatantID] = cleaned
        }
        return enforceUniqueEquippedItems(resolved)
    }

    static func enforceUniqueEquippedItems(
        _ loadouts: [String: EquipmentLoadout],
        prioritizing combatantID: String? = nil,
    ) -> [String: EquipmentLoadout] {
        var orderedIDs = loadouts.keys.sorted()
        if let combatantID {
            orderedIDs.removeAll { $0 == combatantID }
            orderedIDs.insert(combatantID, at: 0)
        }
        var claimedItemIDs = Set<String>()
        var unique: [String: EquipmentLoadout] = [:]
        for combatantID in orderedIDs {
            guard let loadout = loadouts[combatantID] else { continue }
            var slots: [ItemSlot: String] = [:]
            for slot in ItemSlot.allCases {
                guard let itemID = loadout.itemID(for: slot), claimedItemIDs.insert(itemID).inserted else { continue }
                slots[slot] = itemID
            }
            unique[combatantID] = EquipmentLoadout(itemIDsBySlot: slots)
        }
        return unique
    }

    static func applyLoadout(
        _ loadout: EquipmentLoadout,
        for combatantID: String,
        in loadouts: [String: EquipmentLoadout],
    ) -> [String: EquipmentLoadout] {
        // The edited combatant claims items first; untouched loadouts retain
        // the same catalog-slot and combatant-ID precedence as sanitization.
        var updated = loadouts
        updated[combatantID] = loadout
        return enforceUniqueEquippedItems(updated, prioritizing: combatantID)
    }
}
