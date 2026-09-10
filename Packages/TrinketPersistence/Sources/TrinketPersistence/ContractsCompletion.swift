import TrinketContent
import TrinketCore

public enum ContractsCompletion {
    public static func resolveLoot(
        for offer: ContractOffer,
        encounterLevel: Int,
        save: PlayerSave,
    ) -> BattleLootResult {
        VictoryRewardApplier.resolveLoot(
            LootRequest(
                rewardLevel: encounterLevel,
                seedSalt: "battle-loot-contract-\(offer.id)",
                itemID: rewardItemID(offerID: offer.id),
            ),
            encounterLevel: encounterLevel,
            enemyIsBoss: VictoryRewardApplier.isBoss(enemyID: offer.enemyID),
            worldSeed: save.worldSeed,
            ownership: RewardOwnership(save),
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
        )
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
    ) -> Bool {
        guard save.contracts.replace(offerID: offerID) else { return false }
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
        return true
    }

    private static func rewardItemID(offerID: String) -> String {
        "contract-\(offerID)-loot"
    }
}
