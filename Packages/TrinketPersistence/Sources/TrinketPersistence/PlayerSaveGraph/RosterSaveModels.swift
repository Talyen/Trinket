import Foundation
import SwiftData
import TrinketContent
import TrinketCore

@Model
final class RosterModel {
    var activeHeroID: String = PlayerRosterState.starterHeroID
    var activeCompanionID: String = PlayerRosterState.starterCompanionID
    var gold: Int = 0
    var root: PlayerSaveRoot?

    @Relationship(deleteRule: .cascade, inverse: \UnlockedCombatantModel.roster)
    var unlockedCombatants: [UnlockedCombatantModel]?
    @Relationship(deleteRule: .cascade, inverse: \CombatantProgressionModel.roster)
    var progressions: [CombatantProgressionModel]?
    @Relationship(deleteRule: .cascade, inverse: \AbilityLoadoutModel.roster)
    var abilityLoadouts: [AbilityLoadoutModel]?
    @Relationship(deleteRule: .cascade, inverse: \EquipmentLoadoutModel.roster)
    var equipmentLoadouts: [EquipmentLoadoutModel]?
    @Relationship(deleteRule: .cascade, inverse: \TalentLoadoutModel.roster)
    var talentLoadouts: [TalentLoadoutModel]?

    init() {}
}

@Model
final class TalentLoadoutModel {
    var combatantID: String = ""
    var roster: RosterModel?

    @Relationship(deleteRule: .cascade, inverse: \TalentNodeUnlockModel.loadout)
    var unlockedNodes: [TalentNodeUnlockModel]?

    init(combatantID: String = "") {
        self.combatantID = combatantID
    }
}

@Model
final class TalentNodeUnlockModel {
    var nodeID: String = ""
    var loadout: TalentLoadoutModel?

    init(nodeID: String = "") {
        self.nodeID = nodeID
    }
}

@Model
final class UnlockedCombatantModel {
    var combatantID: String = ""
    var role: String = ""
    var roster: RosterModel?

    /// Shared by persisted rows and incoming unlocks during reconciliation.
    static func key(role: String, combatantID: String) -> String {
        "\(role):\(combatantID)"
    }

    var compositeKey: String {
        Self.key(role: role, combatantID: combatantID)
    }

    init(combatantID: String = "", role: String = "") {
        self.combatantID = combatantID
        self.role = role
    }
}

@Model
final class CombatantProgressionModel {
    var combatantID: String = ""
    var level: Int = 1
    var currentXP: Int = 0
    var requiredXP: Int = CombatantProgression.requiredXP(forLevel: 1)
    var roster: RosterModel?

    init(combatantID: String = "", progression: CombatantProgression = .initial) {
        self.combatantID = combatantID
        level = progression.level
        currentXP = progression.currentXP
        requiredXP = progression.requiredXP
    }
}

@Model
final class AbilityLoadoutModel {
    var combatantID: String = ""
    var basicID: String?
    var skillID: String?
    var ultimateID: String?
    var roster: RosterModel?

    init(combatantID: String = "", loadout: AbilityLoadout = AbilityLoadout()) {
        self.combatantID = combatantID
        basicID = loadout.basic?.id
        skillID = loadout.skill?.id
        ultimateID = loadout.ultimate?.id
    }
}

@Model
final class EquipmentLoadoutModel {
    var combatantID: String = ""
    var roster: RosterModel?

    @Relationship(deleteRule: .cascade, inverse: \EquipmentSlotModel.loadout)
    var slots: [EquipmentSlotModel]?

    init(combatantID: String = "") {
        self.combatantID = combatantID
    }
}

@Model
final class EquipmentSlotModel {
    var slotID: String = ""
    var itemID: String = ""
    var loadout: EquipmentLoadoutModel?

    init(slotID: String = "", itemID: String = "") {
        self.slotID = slotID
        self.itemID = itemID
    }
}
