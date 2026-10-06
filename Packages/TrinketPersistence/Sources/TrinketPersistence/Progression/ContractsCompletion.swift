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
        BattleLoot.resolve(
            .contract(
                offerID: offer.id,
                modifier: effectiveModifier(for: offer, inventory: save.inventory),
            ),
            encounterLevel: encounterLevel,
            enemyIsBoss: VictoryRewardApplier.isBoss(enemyID: offer.enemyID),
            worldSeed: save.worldSeed,
            ownership: RewardOwnership(save),
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
        )
    }

    @discardableResult
    static func complete(
        offerID: String,
        hero: Combatant,
        companion: Combatant,
        encounterLevel: Int,
        loot: BattleLootResult,
        battleGold: BattleGoldFlow = .init(),
        award: BattleRewardSettlement? = nil,
        save: inout PlayerSave,
        makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
        recordReceipt: (SaveEconomicReceipt) -> Void,
    ) -> EncounterCompletion {
        guard !(save.contracts.completedOfferIDs ?? []).contains(offerID),
              let offer = save.contracts.offers.first(where: { $0.id == offerID }) else { return .alreadyCompleted }
        let modifier = effectiveModifier(for: offer, inventory: save.inventory)
        VictoryRewardApplier.grantVictoryRewards(
            party: (hero, companion),
            encounterLevel: encounterLevel,
            stageGold: loot.gold,
            battleGold: battleGold,
            award: award,
            experienceEarnedPercent: modifier.experienceBonusPercent,
            materialRewards: loot.materials,
            item: loot.item,
            save: &save, claim: .contract(offerID), recordReceipt: recordReceipt,
        )
        save.contracts.replace(
            offerID: offerID, eligibleModifiers: eligibleModifiers(in: save.inventory), makeOffer: makeOffer,
        )
        save.contracts.earnRefresh()
        return .completed
    }
}
