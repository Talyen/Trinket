import TrinketContent
import TrinketCore

/// A rejected choice never writes; a failed durable commit may be retried.
public enum RosterEditResult: Equatable, Sendable {
    case committed
    case unavailable
    case persistenceFailed
}

/// Intent only: Persistence resolves catalog choices and owned items at commit time.
public enum CombatantLoadoutEdit {
    case selectAbility(abilityID: String)
    case equipItem(itemID: String, slot: ItemSlot)
    case unequipItem(ItemSlot)
    case resetTalents
}

extension PlayerSave {
    mutating func applyLoadoutEdit(_ edit: CombatantLoadoutEdit, for combatantID: String, access: ContentAccessPolicy) -> Bool {
        guard let combatant = roster.editableCombatant(id: combatantID, access: access) else { return false }
        switch edit {
        case let .selectAbility(abilityID):
            let choices = combatant.abilityChoices
            guard let ability = (choices.basics + choices.skills + choices.ultimates).first(where: { $0.id == abilityID })
            else { return false }
            roster.setLoadout(roster.loadout(for: combatant).selecting(ability), for: combatant)
        case let .equipItem(itemID, slot):
            guard let item = inventory.items.first(where: { $0.id == itemID }) else { return false }
            var equipment = roster.equipmentLoadout(for: combatant)
            guard equipment.canEquip(item, in: slot, inventory: inventory.items) else { return false }
            equipment.equip(item, in: slot, inventory: inventory.items)
            roster.setEquipmentLoadout(equipment, for: combatant)
        case let .unequipItem(slot):
            var equipment = roster.equipmentLoadout(for: combatant)
            equipment.unequip(slot)
            roster.setEquipmentLoadout(equipment, for: combatant)
        case .resetTalents:
            roster.resetTalents(for: combatantID)
        }
        return true
    }

    mutating func applyPartySelection(heroID: String?, companionID: String?, access: ContentAccessPolicy) -> Bool {
        guard heroID != nil || companionID != nil else { return false }
        let hero = heroID.flatMap { roster.editableCombatant(id: $0, access: access) }
        let companion = companionID.flatMap { roster.editableCombatant(id: $0, access: access) }
        // Validate the whole selection before changing either party slot.
        guard heroID == nil || hero?.role == .hero,
              companionID == nil || companion?.role == .companion else { return false }
        if let hero {
            roster.setActiveHero(hero)
        }
        if let companion {
            roster.setActiveCompanion(companion)
        }
        return true
    }

    mutating func applyTalentUnlock(nodeID: String, treeID: String, for combatantID: String, access: ContentAccessPolicy) -> Bool {
        guard let combatant = roster.editableCombatant(id: combatantID, access: access),
              let config = CombatantTalentCatalog.configIfAvailable(for: combatantID),
              let tree = config.tree(matching: treeID),
              let node = tree.node(matching: nodeID) else { return false }
        var candidate = roster
        guard candidate.unlockTalent(node: node, inTree: tree, for: combatantID) else { return false }
        let unlocked = candidate.unlockedTalents(for: combatantID)
        guard config.cappedUnlocks(unlocked, budget: candidate.progression(for: combatant).totalTalentPoints) == unlocked
        else { return false }
        roster = candidate
        return true
    }
}

private extension PlayerRosterState {
    func editableCombatant(id: String, access: ContentAccessPolicy) -> Combatant? {
        guard access.allowsCombatant(id), let combatant = GameContent.combatant(matching: id),
              isUnlocked(combatant) else { return nil }
        return combatant
    }
}
