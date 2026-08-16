import Foundation
import SwiftData
import TrinketContent
import TrinketCore

@Model
public final class RosterModel {
    public var activeHeroID: String = PlayerRosterState.starterHeroID
    public var activeCompanionID: String = PlayerRosterState.starterCompanionID
    public var gold: Int = 0
    public var root: PlayerSaveRoot?

    @Relationship(deleteRule: .cascade, inverse: \UnlockedCombatantModel.roster)
    public var unlockedCombatants: [UnlockedCombatantModel]?
    @Relationship(deleteRule: .cascade, inverse: \CombatantProgressionModel.roster)
    public var progressions: [CombatantProgressionModel]?
    @Relationship(deleteRule: .cascade, inverse: \AbilityLoadoutModel.roster)
    public var abilityLoadouts: [AbilityLoadoutModel]?
    @Relationship(deleteRule: .cascade, inverse: \EquipmentLoadoutModel.roster)
    public var equipmentLoadouts: [EquipmentLoadoutModel]?
    @Relationship(deleteRule: .cascade, inverse: \TalentLoadoutModel.roster)
    public var talentLoadouts: [TalentLoadoutModel]?

    public init() {}
}

@Model
public final class TalentLoadoutModel {
    public var combatantID: String = ""
    public var roster: RosterModel?

    @Relationship(deleteRule: .cascade, inverse: \TalentNodeUnlockModel.loadout)
    public var unlockedNodes: [TalentNodeUnlockModel]?

    public init(combatantID: String = "") {
        self.combatantID = combatantID
    }
}

@Model
public final class TalentNodeUnlockModel {
    public var nodeID: String = ""
    public var loadout: TalentLoadoutModel?

    public init(nodeID: String = "") {
        self.nodeID = nodeID
    }
}

@Model
public final class UnlockedCombatantModel {
    public var combatantID: String = ""
    public var role: String = ""
    public var roster: RosterModel?

    public init(combatantID: String = "", role: String = "") {
        self.combatantID = combatantID
        self.role = role
    }
}

@Model
public final class CombatantProgressionModel {
    public var combatantID: String = ""
    public var level: Int = 1
    public var currentXP: Int = 0
    public var requiredXP: Int = CombatantProgression.requiredXP(forLevel: 1)
    public var roster: RosterModel?

    public init(combatantID: String = "", progression: CombatantProgression = .initial) {
        self.combatantID = combatantID
        level = progression.level
        currentXP = progression.currentXP
        requiredXP = progression.requiredXP
    }
}

@Model
public final class AbilityLoadoutModel {
    public var combatantID: String = ""
    public var basicID: String?
    public var skillID: String?
    public var ultimateID: String?
    public var roster: RosterModel?

    public init(combatantID: String = "", loadout: AbilityLoadout = AbilityLoadout()) {
        self.combatantID = combatantID
        basicID = loadout.basic?.id
        skillID = loadout.skill?.id
        ultimateID = loadout.ultimate?.id
    }
}

@Model
public final class EquipmentLoadoutModel {
    public var combatantID: String = ""
    public var roster: RosterModel?

    @Relationship(deleteRule: .cascade, inverse: \EquipmentSlotModel.loadout)
    public var slots: [EquipmentSlotModel]?

    public init(combatantID: String = "") {
        self.combatantID = combatantID
    }
}

@Model
public final class EquipmentSlotModel {
    public var slotID: String = ""
    public var itemID: String = ""
    public var loadout: EquipmentLoadoutModel?

    public init(slotID: String = "", itemID: String = "") {
        self.slotID = slotID
        self.itemID = itemID
    }
}
