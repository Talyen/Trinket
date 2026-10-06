import TrinketContent
import TrinketCore

enum BattleExperienceReward {
    @discardableResult
    static func apply(
        _ settlement: BattleRewardSettlement,
        hero: Combatant,
        companion: Combatant,
        save: inout PlayerSave,
        recordReceipt: (SaveEconomicReceipt) -> Void,
    ) -> SaveEconomicReceipt {
        var experience: [String: Int] = [:]
        for (combatant, quantity) in [(hero, settlement.award.heroExperience), (companion, settlement.award.companionExperience)] {
            let granted = save.roster.grantExperience(quantity, to: combatant)
            if granted > 0 {
                experience[combatant.id, default: 0] += granted
            }
        }
        let receipt = SaveEconomicReceipt(kind: .reward, effects: .committed(experience: experience))
        recordReceipt(receipt)
        return receipt
    }
}
