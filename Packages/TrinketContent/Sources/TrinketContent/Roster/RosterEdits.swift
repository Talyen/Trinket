import TrinketCore

/// A roster choice resolved against current catalog, access, and owned item values.
public enum CombatantLoadoutEdit {
    case selectAbility(abilityID: String)
    case equipItem(itemID: String, slot: ItemSlot)
    case unequipItem(ItemSlot)
    case resetTalents
}

public extension PlayerRosterState {
    mutating func applyLoadoutEdit(
        _ edit: CombatantLoadoutEdit,
        for combatantID: String,
        inventory: [InventoryItem],
        access: ContentAccessPolicy,
    ) -> Bool {
        guard let combatant = editableCombatant(id: combatantID, access: access) else { return false }
        switch edit {
        case let .selectAbility(abilityID):
            let choices = combatant.abilityChoices
            guard let ability = (choices.basics + choices.skills + choices.ultimates).first(where: { $0.id == abilityID })
            else { return false }
            setLoadout(loadout(for: combatant).selecting(ability), for: combatant)
        case let .equipItem(itemID, slot):
            guard combatant.role.equipmentSlots.contains(slot),
                  let item = inventory.first(where: { $0.id == itemID }) else { return false }
            var equipment = equipmentLoadout(for: combatant)
            guard equipment.canEquip(item, in: slot, inventory: inventory) else { return false }
            equipment.equip(item, in: slot, inventory: inventory)
            setEquipmentLoadout(equipment, for: combatant)
        case let .unequipItem(slot):
            guard combatant.role.equipmentSlots.contains(slot) else { return false }
            var equipment = equipmentLoadout(for: combatant)
            equipment.unequip(slot)
            setEquipmentLoadout(equipment, for: combatant)
        case .resetTalents:
            resetTalents(for: combatantID)
        }
        return true
    }

    mutating func applyPartySelection(heroID: String?, companionID: String?, access: ContentAccessPolicy) -> Bool {
        guard heroID != nil || companionID != nil else { return false }
        let hero = heroID.flatMap { editableCombatant(id: $0, access: access) }
        let companion = companionID.flatMap { editableCombatant(id: $0, access: access) }
        // Validate the whole selection before changing either party slot.
        guard heroID == nil || hero?.role == .hero,
              companionID == nil || companion?.role == .companion else { return false }
        if let hero {
            setActiveHero(hero)
        }
        if let companion {
            setActiveCompanion(companion)
        }
        return true
    }

    mutating func applyTalentUnlock(nodeID: String, treeID: String, for combatantID: String, access: ContentAccessPolicy) -> Bool {
        guard let combatant = editableCombatant(id: combatantID, access: access),
              let config = CombatantTalentCatalog.configIfAvailable(for: combatantID),
              let tree = config.tree(matching: treeID),
              let node = tree.node(matching: nodeID) else { return false }
        var candidate = self
        guard candidate.unlockTalent(node: node, inTree: tree, for: combatantID) else { return false }
        let unlocked = candidate.unlockedTalents(for: combatantID)
        guard config.cappedUnlocks(unlocked, budget: candidate.progression(for: combatant).totalTalentPoints) == unlocked
        else { return false }
        self = candidate
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
