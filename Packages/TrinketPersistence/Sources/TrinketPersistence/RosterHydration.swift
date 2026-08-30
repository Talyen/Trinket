import Foundation
import TrinketContent
import TrinketCore

enum RosterHydration {
    static func resolveEquipmentSlot(
        _ rawValue: String,
        schemaVersion: Int,
        isHero: Bool,
    ) -> ItemSlot? {
        guard schemaVersion < PlayerSave.Schema.renamedItemSlots else { return ItemSlot(rawValue: rawValue) }
        return switch rawValue {
        case "Trinket": .accessory
        case "Secondary Trinket": isHero ? .secondaryAccessory : nil
        case "Tertiary Trinket": nil
        default: ItemSlot(rawValue: rawValue)
        }
    }

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

    static func resolveAbilityLoadouts(
        from loadouts: [String: AbilityLoadout],
    ) -> [String: AbilityLoadout] {
        resolvedAbilities(loadouts.mapValues(rawIDs(of:)))
    }

    static func resolveAbilityLoadouts(
        from ids: [String: AbilityLoadoutIDs],
    ) -> [String: AbilityLoadout] {
        resolvedAbilities(ids)
    }

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
        if let match = choices.first(where: { $0.id == id }) {
            return match
        }
        if let remappedID = LegacyIDRemap.remappedAbilityID(id) {
            return choices.first(where: { $0.id == remappedID })
        }
        return nil
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
        let tierChoices = choices.abilities(for: tier)
        if let match = tierChoices.first(where: { $0.id == id }) {
            return match
        }
        if let remappedID = LegacyIDRemap.remappedAbilityID(id),
           let match = tierChoices.first(where: { $0.id == remappedID }) {
            return match
        }
        return fallback
    }

    struct AbilityLoadoutIDs {
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
        var unique = EquipmentLoadout()
        var claimedItemIDs = Set<String>()
        for slot in ItemSlot.allCases {
            guard let itemID = loadout.itemID(for: slot), claimedItemIDs.insert(itemID).inserted else {
                continue
            }
            unique.itemIDsBySlot[slot] = itemID
        }
        return unique
    }

    static func enforceUniqueEquippedItems(
        _ loadouts: [String: EquipmentLoadout],
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

    static func applyLoadout(
        _ loadout: EquipmentLoadout,
        for combatantID: String,
        in loadouts: [String: EquipmentLoadout],
    ) -> [String: EquipmentLoadout] {
        let resolved = deduplicateWithinLoadout(loadout)
        let newlyEquipped = Set(resolved.itemIDsBySlot.values)
        var updated = loadouts
        for (otherID, otherLoadout) in loadouts where otherID != combatantID {
            var cleaned = otherLoadout
            for slot in ItemSlot.allCases {
                if let itemID = cleaned.itemID(for: slot), newlyEquipped.contains(itemID) {
                    cleaned.unequip(slot)
                }
            }
            updated[otherID] = cleaned
        }
        updated[combatantID] = resolved
        return updated
    }
}
