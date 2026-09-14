import TrinketContent
import TrinketCore

public enum BattleExperienceReward {
    public static func apply(
        _ settlement: BattleRewardSettlement,
        hero: Combatant,
        companion: Combatant,
        save: inout PlayerSave,
    ) {
        save.roster.grantExperience(settlement.award.heroExperience, to: hero)
        save.roster.grantExperience(settlement.award.companionExperience, to: companion)
    }
}
