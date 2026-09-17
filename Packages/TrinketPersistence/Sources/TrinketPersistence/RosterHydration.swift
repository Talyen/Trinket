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

    /// Sanitizer path: unknown/missing ability IDs fall back to catalog
    /// defaults so the roster stays playable. The model/cloud read path uses
    /// `rawAbilityLoadouts` (exact match, unknown → nil) to preserve stored
    /// IDs verbatim; sanitize upgrades them later. The divergence is
    /// intentional: read preserves, sanitize heals.
    static func resolveAbilityLoadouts(
        from loadouts: [String: AbilityLoadout],
    ) -> [String: AbilityLoadout] {
        resolvedAbilities(loadouts.mapValues(rawIDs(of:)))
    }

    /// Model/cloud read path: exact match only. Unknown combatants are
    /// dropped; unknown ability IDs become nil (not defaults) so a later
    /// sanitize can distinguish "stored unknown" from "stored missing".
    static func rawAbilityLoadouts(
        from ids: [String: AbilityLoadoutIDs],
    ) -> [String: AbilityLoadout] {
        var resolved: [String: AbilityLoadout] = [:]
        for (combatantID, loadoutIDs) in ids {
            guard let combatant = GameContent.combatant(matching: combatantID) else { continue }
            let choices = combatant.abilityChoices
            resolved[combatantID] = AbilityLoadout(
                basic: exactAbility(loadoutIDs.basicID, choices: choices.abilities(for: .basic)),
                skill: exactAbility(loadoutIDs.skillID, choices: choices.abilities(for: .skill)),
                ultimate: exactAbility(loadoutIDs.ultimateID, choices: choices.abilities(for: .ultimate)),
            )
        }
        return resolved
    }

    private static func exactAbility(_ id: String?, choices: [Ability]) -> Ability? {
        guard let id else { return nil }
        return choices.first(where: { $0.id == id })
    }

    private static func resolvedAbilities(
        _ loadouts: [String: AbilityLoadoutIDs],
    ) -> [String: AbilityLoadout] {
        var resolved: [String: AbilityLoadout] = [:]
        for (combatantID, ids) in loadouts {
            guard let combatant = GameContent.combatant(matching: combatantID) else { continue }
            resolved[combatantID] = resolvedLoadout(
                ids,
                defaults: combatant.abilityLoadout,
                choices: combatant.abilityChoices,
            )
        }
        return resolved
    }

    private static func resolvedLoadout(
        _ ids: AbilityLoadoutIDs,
        defaults: AbilityLoadout,
        choices: AbilityChoices,
    ) -> AbilityLoadout {
        AbilityLoadout(
            basic: resolvedAbility(ids.basicID, tier: .basic, fallback: defaults.basic, choices: choices),
            skill: resolvedAbility(ids.skillID, tier: .skill, fallback: defaults.skill, choices: choices),
            ultimate: resolvedAbility(ids.ultimateID, tier: .ultimate, fallback: defaults.ultimate, choices: choices),
        )
    }

    private static func resolvedAbility(
        _ id: String?,
        tier: AbilityTier,
        fallback: Ability?,
        choices: AbilityChoices,
    ) -> Ability? {
        guard let id else { return fallback }
        return exactAbility(id, choices: choices.abilities(for: tier)) ?? fallback
    }

    struct AbilityLoadoutIDs: Codable, Equatable, Sendable {
        var basicID: String?
        var skillID: String?
        var ultimateID: String?
    }

    private static func rawIDs(of loadout: AbilityLoadout) -> AbilityLoadoutIDs {
        AbilityLoadoutIDs(basicID: loadout.basic?.id, skillID: loadout.skill?.id, ultimateID: loadout.ultimate?.id)
    }

    static func resolveEquipmentLoadout(
        _ loadout: EquipmentLoadout,
        inventoryItemIDs: Set<String>,
        combatant: Combatant? = nil,
        inventoryItems: [InventoryItem]? = nil,
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

    static func resolveEquipmentLoadouts(
        from loadouts: [String: EquipmentLoadout],
        inventoryItemIDs: Set<String>,
        inventoryItems: [InventoryItem]? = nil,
    ) -> [String: EquipmentLoadout] {
        var resolved: [String: EquipmentLoadout] = [:]
        for (combatantID, loadout) in loadouts {
            let combatant = GameContent.combatant(matching: combatantID)
            // Unknown-combatant drop is active only when inventory items are
            // supplied (sanitizer path). Model/cloud read paths build
            // equipment directly from stored rows and leave dangling refs for
            // sanitize to strip, so a raw round trip never loses data here.
            if inventoryItems != nil, combatant == nil {
                continue
            }
            resolved[combatantID] = resolveEquipmentLoadout(
                loadout,
                inventoryItemIDs: inventoryItemIDs,
                combatant: combatant,
                inventoryItems: inventoryItems,
            )
        }
        return enforceUniqueEquippedItems(resolved)
    }

    static func deduplicateWithinLoadout(_ loadout: EquipmentLoadout) -> EquipmentLoadout {
        var claimedItemIDs = Set<String>()
        return EquipmentLoadout(itemIDsBySlot: deduplicatedSlots(in: loadout, claimedItemIDs: &claimedItemIDs))
    }

    static func enforceUniqueEquippedItems(
        _ loadouts: [String: EquipmentLoadout],
    ) -> [String: EquipmentLoadout] {
        var claimedItemIDs = Set<String>()
        var unique: [String: EquipmentLoadout] = [:]
        for combatantID in loadouts.keys.sorted() {
            guard let loadout = loadouts[combatantID] else { continue }
            unique[combatantID] = EquipmentLoadout(
                itemIDsBySlot: deduplicatedSlots(in: loadout, claimedItemIDs: &claimedItemIDs),
            )
        }
        return unique
    }

    /// Single slot-dedup core shared by within-loadout and cross-loadout
    /// passes. Iterates `ItemSlot.allCases` in order, keeping the first
    /// occurrence of each item ID and skipping the rest.
    private static func deduplicatedSlots(
        in loadout: EquipmentLoadout,
        claimedItemIDs: inout Set<String>,
    ) -> [ItemSlot: String] {
        var cleaned: [ItemSlot: String] = [:]
        for slot in ItemSlot.allCases {
            guard let itemID = loadout.itemID(for: slot) else { continue }
            guard claimedItemIDs.insert(itemID).inserted else { continue }
            cleaned[slot] = itemID
        }
        return cleaned
    }

    static func applyLoadout(
        _ loadout: EquipmentLoadout,
        for combatantID: String,
        in loadouts: [String: EquipmentLoadout],
    ) -> [String: EquipmentLoadout] {
        let resolved = deduplicateWithinLoadout(loadout)
        let newlyEquipped = Set(resolved.itemIDsBySlot.values)
        var updated = loadouts
        for (otherID, otherLoadout) in loadouts where otherID != combatantID {
            updated[otherID] = loadoutRemoving(otherLoadout, itemIDs: newlyEquipped)
        }
        updated[combatantID] = resolved
        // Final canonical pass: the edited entry already won (others were
        // stripped of its items), so this only heals pre-existing dupes
        // among untouched loadouts, matching sanitize.
        return enforceUniqueEquippedItems(updated)
    }

    /// Removes every slot holding one of the given items.
    private static func loadoutRemoving(_ loadout: EquipmentLoadout, itemIDs: Set<String>) -> EquipmentLoadout {
        var cleaned = loadout
        for slot in ItemSlot.allCases {
            if let itemID = cleaned.itemID(for: slot), itemIDs.contains(itemID) {
                cleaned.unequip(slot)
            }
        }
        return cleaned
    }
}
