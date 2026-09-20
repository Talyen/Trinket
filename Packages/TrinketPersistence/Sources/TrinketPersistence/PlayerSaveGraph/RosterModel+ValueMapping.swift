import Foundation
import SwiftData
import TrinketContent
import TrinketCore

private struct UnlockedCombatantValue {
    static let heroRole = "hero"
    static let companionRole = "companion"

    let combatantID: String
    let role: String

    var key: String {
        UnlockedCombatantModel.key(role: role, combatantID: combatantID)
    }
}

private struct EquipmentLoadoutValue {
    let combatantID: String
    let loadout: EquipmentLoadout
}

extension RosterModel {
    private func updateEquipmentLoadout(
        _ model: EquipmentLoadoutModel,
        from value: EquipmentLoadoutValue,
        context: ModelContext?,
    ) {
        model.combatantID = value.combatantID
        let slots = value.loadout.itemIDsBySlot
            .map { (slotID: $0.key.rawValue, itemID: $0.value) }
            .sorted { $0.slotID < $1.slotID }
        model.slots = reconcileModels(
            existing: model.slots ?? [],
            values: slots,
            existingKey: \.slotID,
            valueKey: { $0.slotID },
            make: { _ in EquipmentSlotModel() },
            update: { slotModel, slot in
                slotModel.slotID = slot.slotID
                slotModel.itemID = slot.itemID
            },
            link: { $0.loadout = model },
            context: context,
        )
    }
}

extension RosterModel {
    func update(from roster: PlayerRosterState, context: ModelContext?) {
        activeHeroID = roster.activeHeroID
        activeCompanionID = roster.activeCompanionID
        gold = roster.gold
        updateUnlockedCombatants(from: roster, context: context)
        updateProgressions(from: roster, context: context)
        updateAbilityLoadouts(from: roster, context: context)
        updateTalentLoadouts(from: roster, context: context)
        updateEquipmentLoadouts(from: roster, context: context)
    }

    private func updateUnlockedCombatants(from roster: PlayerRosterState, context: ModelContext?) {
        let unlockedValues = roster.unlockedHeroIDs.sorted().map {
            UnlockedCombatantValue(combatantID: $0, role: UnlockedCombatantValue.heroRole)
        } + roster.unlockedCompanionIDs.sorted().map {
            UnlockedCombatantValue(combatantID: $0, role: UnlockedCombatantValue.companionRole)
        }
        unlockedCombatants = reconcileModels(
            existing: unlockedCombatants ?? [],
            values: unlockedValues,
            existingKey: \UnlockedCombatantModel.compositeKey,
            valueKey: { $0.key },
            make: { _ in UnlockedCombatantModel() },
            update: { model, value in
                model.combatantID = value.combatantID
                model.role = value.role
            },
            link: { $0.roster = self },
            context: context,
        )
    }

    private func updateProgressions(from roster: PlayerRosterState, context: ModelContext?) {
        let progressionValues = roster.progressions.sorted { $0.key < $1.key }
        progressions = reconcileModels(
            existing: progressions ?? [],
            values: progressionValues,
            existingKey: \.combatantID,
            valueKey: { $0.key },
            make: { _ in CombatantProgressionModel() },
            update: { model, value in
                model.combatantID = value.key
                model.level = value.value.level
                model.currentXP = value.value.currentXP
                model.requiredXP = value.value.requiredXP
            },
            link: { $0.roster = self },
            context: context,
        )
    }

    private func updateAbilityLoadouts(from roster: PlayerRosterState, context: ModelContext?) {
        let abilityValues = roster.abilityLoadouts.sorted { $0.key < $1.key }
        abilityLoadouts = reconcileModels(
            existing: abilityLoadouts ?? [],
            values: abilityValues,
            existingKey: \.combatantID,
            valueKey: { $0.key },
            make: { _ in AbilityLoadoutModel() },
            update: { model, value in
                model.combatantID = value.key
                model.basicID = value.value.basic?.id
                model.skillID = value.value.skill?.id
                model.ultimateID = value.value.ultimate?.id
            },
            link: { $0.roster = self },
            context: context,
        )
    }

    private func updateTalentLoadouts(from roster: PlayerRosterState, context: ModelContext?) {
        let talentValues = roster.unlockedTalents
            .map { (combatantID: $0.key, nodeIDs: Array($0.value).sorted()) }
            .sorted { $0.combatantID < $1.combatantID }
        talentLoadouts = reconcileModels(
            existing: talentLoadouts ?? [],
            values: talentValues,
            existingKey: \.combatantID,
            valueKey: { $0.combatantID },
            make: { _ in TalentLoadoutModel() },
            update: { model, value in
                self.updateTalentLoadout(model, from: value, context: context)
            },
            link: { $0.roster = self },
            context: context,
        )
    }

    private func updateTalentLoadout(
        _ model: TalentLoadoutModel,
        from value: (combatantID: String, nodeIDs: [String]),
        context: ModelContext?,
    ) {
        model.combatantID = value.combatantID
        model.unlockedNodes = reconcileModels(
            existing: model.unlockedNodes ?? [],
            values: value.nodeIDs,
            existingKey: \.nodeID,
            valueKey: { $0 },
            make: { _ in TalentNodeUnlockModel() },
            update: { unlockModel, nodeID in
                unlockModel.nodeID = nodeID
            },
            link: { $0.loadout = model },
            context: context,
        )
    }

    private func updateEquipmentLoadouts(from roster: PlayerRosterState, context: ModelContext?) {
        let equipmentValues = roster.equipmentLoadouts
            .map { EquipmentLoadoutValue(combatantID: $0.key, loadout: $0.value) }
            .sorted { $0.combatantID < $1.combatantID }
        equipmentLoadouts = reconcileModels(
            existing: equipmentLoadouts ?? [],
            values: equipmentValues,
            existingKey: \.combatantID,
            valueKey: { $0.combatantID },
            make: { _ in EquipmentLoadoutModel() },
            update: { model, value in
                self.updateEquipmentLoadout(model, from: value, context: context)
            },
            link: { $0.roster = self },
            context: context,
        )
    }
}

extension RosterModel {
    /// Graph rows the value read drops silently and value-level `changed()`
    /// therefore never sees: ability loadouts for unknown combatants
    /// (`rawAbilityLoadouts` filters them), unlocked rows with invalid roles,
    /// and equipment slots with invalid slot IDs. Repair must detect them
    /// here; the next `update(from:)` reconcile deletes the orphans.
    /// Unknown combatants in progressions/talents/equipment stay visible at
    /// value level (sanitize strips them), so they need no graph check.
    var hasDanglingRosterChildren: Bool {
        if let unlocked = unlockedCombatants, unlocked.contains(where: {
            $0.role != UnlockedCombatantValue.heroRole && $0.role != UnlockedCombatantValue.companionRole
        }) {
            return true
        }
        if let abilities = abilityLoadouts, abilities.contains(where: {
            GameContent.combatant(matching: $0.combatantID) == nil
        }) {
            return true
        }
        for loadout in equipmentLoadouts ?? [] {
            if let slots = loadout.slots, slots.contains(where: { ItemSlot(rawValue: $0.slotID) == nil }) {
                return true
            }
        }
        return false
    }

    func toPlayerRosterState() -> PlayerRosterState {
        let unlocked = unlockedCombatants ?? []
        let heroIDs = Set(unlocked.filter { $0.role == UnlockedCombatantValue.heroRole }.map(\.combatantID))
        let companionIDs = Set(unlocked.filter { $0.role == UnlockedCombatantValue.companionRole }.map(\.combatantID))
        let progressionValues = Dictionary(
            (progressions ?? []).map {
                ($0.combatantID, CombatantProgression(level: $0.level, currentXP: $0.currentXP, requiredXP: $0.requiredXP))
            },
            uniquingKeysWith: { _, new in new },
        )
        let abilityIDValues = Dictionary(
            (abilityLoadouts ?? []).map {
                ($0.combatantID, RosterHydration.AbilityLoadoutIDs(basicID: $0.basicID, skillID: $0.skillID, ultimateID: $0.ultimateID))
            },
            uniquingKeysWith: { _, new in new },
        )
        let equipmentValues = Dictionary(
            (equipmentLoadouts ?? []).map { loadoutModel in
                (
                    loadoutModel.combatantID,
                    EquipmentLoadout(itemIDsBySlot: Dictionary(
                        (loadoutModel.slots ?? []).compactMap { slot in
                            let resolvedSlot = ItemSlot(rawValue: slot.slotID)
                            return resolvedSlot.map { ($0, slot.itemID) }
                        },
                        uniquingKeysWith: { _, new in new },
                    )),
                )
            },
            uniquingKeysWith: { _, new in new },
        )
        let talentValues = Dictionary(
            (talentLoadouts ?? []).map { loadoutModel in
                (loadoutModel.combatantID, Set((loadoutModel.unlockedNodes ?? []).map(\.nodeID)))
            },
            uniquingKeysWith: { _, new in new },
        )

        return PlayerRosterState(
            activeHeroID: activeHeroID,
            activeCompanionID: activeCompanionID,
            unlockedHeroIDs: heroIDs,
            unlockedCompanionIDs: companionIDs,
            abilityLoadouts: RosterHydration.rawAbilityLoadouts(from: abilityIDValues),
            progressions: progressionValues,
            equipmentLoadouts: equipmentValues,
            unlockedTalents: talentValues,
            gold: gold,
        )
    }
}
