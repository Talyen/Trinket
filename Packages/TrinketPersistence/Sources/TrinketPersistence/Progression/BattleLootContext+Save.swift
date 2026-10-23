import TrinketContent

public extension BattleLootContext {
    init(save: PlayerSave) {
        self.init(
            worldSeed: save.worldSeed,
            ownership: RewardOwnership(save),
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
            claimedJourneyRewardStageIDs: save.journey.claimedRewardStageIDs,
            wishedTemplateID: save.homestead.wishedTemplateID,
            partyBias: PartyLootBias(roster: save.roster),
        )
    }
}
