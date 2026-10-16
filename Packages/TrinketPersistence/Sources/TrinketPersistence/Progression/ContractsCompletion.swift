import TrinketContent
import TrinketCore

enum ContractsCompletion {
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
        let encounterLevel = rewards.encounterLevel(or: EncounterScaling.contract(offer.difficulty)
            .resolve(partyAverageLevel: save.roster.activePartyAverageLevel).level)
        let settlement = rewards.resolve { overrides in
            let loot = overrides.loot ?? BattleLootContext(save: save).contract(for: offer, encounterLevel: encounterLevel)
            let modifier = RewardOwnership(save).resolved(
                offer.rewardModifier,
                enemyIsBoss: GameContent.enemy(matching: offer.enemyID)?.isBoss == true,
            )
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
            offerID: offerID, eligibleModifiers: RewardOwnership(save).eligibleModifiers, makeOffer: makeOffer,
        )
        save.contracts.earnRefresh()
        return .completed
    }
}
