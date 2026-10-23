import TrinketContent
import TrinketCore

enum BattleExperienceReward {
    static func apply(
        _ settlement: BattleRewardSettlement,
        hero: Combatant,
        companion: Combatant,
        save: inout PlayerSave,
    ) {
        for (combatant, quantity) in [(hero, settlement.award.heroExperience), (companion, settlement.award.companionExperience)] {
            _ = save.roster.grantExperience(quantity, to: combatant)
        }
    }
}
