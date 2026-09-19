import TrinketContent
import TrinketCore

public enum ContractsCompletion {
    public static func resolveLoot(
        for offer: ContractOffer,
        encounterLevel: Int,
        save: PlayerSave,
    ) -> BattleLootResult {
        VictoryRewardApplier.resolveLoot(
            .contract(offerID: offer.id, rewardLevel: campaignRewardLevel(in: save)),
            encounterLevel: encounterLevel,
            enemyIsBoss: VictoryRewardApplier.isBoss(enemyID: offer.enemyID),
            worldSeed: save.worldSeed,
            ownership: RewardOwnership(save),
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
        )
    }

    /// Authored tier anchor for contract item generation: the campaign's
    /// current authored level, so tiers follow story progress rather than
    /// grinding. The scaled encounter level still drives XP, gold, and
    /// material quantities. Falls back to the best authored level available
    /// once the campaign is complete.
    static func campaignRewardLevel(in save: PlayerSave, chapters: [Chapter] = GameContent.chapters) -> Int {
        if let stageID = save.journey.activeStageID,
           let stage = chapters.flatMap(\.stages).first(where: { $0.id == stageID }) {
            return StageCompletion.resolvedEncounterLevel(for: stage, in: chapters)
        }
        let authored = chapters.flatMap(\.stages).map { StageCompletion.resolvedEncounterLevel(for: $0, in: chapters) }.max()
        return authored ?? 1
    }

    @discardableResult
    public static func complete(
        offerID: String,
        hero: Combatant,
        companion: Combatant,
        encounterLevel: Int,
        loot: BattleLootResult,
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardSettlement? = nil,
        save: inout PlayerSave,
        makeOffer: (ContractDifficulty, Set<String>) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> EncounterCompletion {
        // `replace` returns false for both unknown offers and already-consumed
        // IDs (consumed IDs are swapped for fresh IDs). Both map to
        // `.alreadyCompleted`: idempotent, grants nothing further.
        guard save.contracts.replace(offerID: offerID, makeOffer: makeOffer) else { return .alreadyCompleted }
        VictoryRewardApplier.grantVictoryRewards(
            hero: hero,
            companion: companion,
            encounterLevel: encounterLevel,
            stageGold: loot.gold,
            battleGold: battleGold,
            award: award,
            materialRewards: loot.materials,
            item: loot.item,
            save: &save,
        )
        return .completed
    }
}
