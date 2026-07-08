import Foundation
import SwiftData
import TrinketCore

@Model
public final class RosterModel {
    public var activeHeroID: String = PlayerRosterState.starterHeroID
    public var activePetID: String = PlayerRosterState.starterPetID
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
    @Relationship(deleteRule: .cascade, inverse: \PrimaryStatsModel.roster)
    public var primaryStats: [PrimaryStatsModel]?

    public init() {}
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

@Model
public final class PrimaryStatsModel {
    public var combatantID: String = ""
    public var strength: Int = 0
    public var agility: Int = 0
    public var toughness: Int = 0
    public var intellect: Int = 0
    public var wisdom: Int = 0
    public var roster: RosterModel?

    public init(combatantID: String = "", stats: PrimaryStats = PrimaryStats()) {
        self.combatantID = combatantID
        strength = stats.strength
        agility = stats.agility
        toughness = stats.toughness
        intellect = stats.intellect
        wisdom = stats.wisdom
    }
}
