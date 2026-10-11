import Foundation
import TrinketContent

public extension MysteryRewardResolver {
    init(save: PlayerSave, at date: Date = Date()) {
        self.init(
            homesteadEffects: save.homestead.effects,
            ownership: RewardOwnership(save),
            inputs: RewardSettlementInputs(
                save: save, hero: save.roster.activeHero, companion: save.roster.activeCompanion, at: date,
            ),
        )
    }
}
