import TrinketContent

public extension BattleLootContext {
    init(save: PlayerSave, worldSeed: UInt64? = nil) {
        self.init(
            worldSeed: worldSeed ?? save.worldSeed,
            ownership: RewardOwnership(save),
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
            claimedJourneyRewardStageIDs: save.journey.claimedRewardStageIDs,
            wishedTemplateID: save.homestead.wishedTemplateID,
            partyBias: PartyLootBias(roster: save.roster),
        )
    }
}
