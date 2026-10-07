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
        rewards: EncounterRewards = .unsettled(.init()),
        save: inout PlayerSave,
        makeOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
        recordReceipt: (SaveEconomicReceipt) -> Void,
    ) -> EncounterCompletion {
        guard !(save.contracts.completedOfferIDs ?? []).contains(offerID),
              let offer = save.contracts.offers.first(where: { $0.id == offerID }) else { return .alreadyCompleted }
        let encounterLevel = rewards.encounterLevel(or: EncounterLevelResolver.contractEnemyLevel(
            difficulty: offer.difficulty, partyAverageLevel: save.roster.activePartyAverageLevel,
        ))
        let settlement = rewards.resolve { overrides in
            let loot = overrides.loot ?? resolveLoot(for: offer, encounterLevel: encounterLevel, save: save)
            let modifier = effectiveModifier(for: offer, inventory: save.inventory)
            return VictoryRewardApplier.settleVictoryRewards(
                party: (hero, companion),
                encounterLevel: encounterLevel,
                stageGold: loot.gold,
                battleGold: overrides.battleGold,
                experienceEarnedPercent: modifier.experienceBonusPercent,
                materialRewards: overrides.materialRewards ?? loot.materials,
                item: overrides.rewardItem ?? loot.item,
                save: save,
            )
        }
        VictoryRewardApplier.apply(
            settlement, hero: hero, companion: companion, save: &save,
            claim: .contract(offerID), recordReceipt: recordReceipt,
        )
        save.contracts.recordVictory(encounterLevel: encounterLevel)
        save.contracts.replace(
            offerID: offerID, eligibleModifiers: eligibleModifiers(in: save.inventory), makeOffer: makeOffer,
        )
        save.contracts.earnRefresh()
        return .completed
    }
}
