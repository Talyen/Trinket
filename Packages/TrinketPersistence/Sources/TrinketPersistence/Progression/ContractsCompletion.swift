import TrinketContent
import TrinketCore

public enum ContractsCompletion {
    public static func effectiveModifier(for offer: ContractOffer, inventory: PlayerInventoryState) -> RewardModifier {
        offer.rewardModifier.resolved(ownedTrinketIDs: inventory.ownedTrinketIDs, ownedUniqueIDs: inventory.ownedUniqueIDs)
    }

    public static func eligibleModifiers(in inventory: PlayerInventoryState) -> [RewardModifier] {
        RewardModifier.eligible(ownedTrinketIDs: inventory.ownedTrinketIDs, ownedUniqueIDs: inventory.ownedUniqueIDs)
    }

    public static func resolveLoot(
        for offer: ContractOffer,
        encounterLevel: Int,
        save: PlayerSave,
    ) -> BattleLootResult {
        VictoryRewardApplier.resolveLoot(
            .contract(
                offerID: offer.id, rewardLevel: campaignRewardLevel(in: save),
                modifier: effectiveModifier(for: offer, inventory: save.inventory),
            ),
            encounterLevel: encounterLevel,
            enemyIsBoss: VictoryRewardApplier.isBoss(enemyID: offer.enemyID),
            worldSeed: save.worldSeed,
            ownership: RewardOwnership(save),
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
        )
    }

    /// Quality of noncombat item offers follows the highest won encounter
    /// level, capped by `CampaignRewardLevel`. Roster levels alone do not
    /// improve those offers.
    static func campaignRewardLevel(in save: PlayerSave, chapters: [Chapter] = GameContent.chapters) -> Int {
        CampaignRewardLevel.resolve(in: save, chapters: chapters)
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
        makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> EncounterCompletion {
        guard let offer = save.contracts.offers.first(where: { $0.id == offerID }) else { return .alreadyCompleted }
        let modifier = effectiveModifier(for: offer, inventory: save.inventory)
        VictoryRewardApplier.grantVictoryRewards(
            hero: hero,
            companion: companion,
            encounterLevel: encounterLevel,
            stageGold: loot.gold,
            battleGold: battleGold,
            award: award,
            experienceEarnedPercent: modifier.experienceBonusPercent,
            materialRewards: loot.materials,
            item: loot.item,
            save: &save,
        )
        save.contracts.replace(
            offerID: offerID, eligibleModifiers: eligibleModifiers(in: save.inventory), makeOffer: makeOffer,
        )
        save.contracts.earnRefresh()
        return .completed
    }
}
