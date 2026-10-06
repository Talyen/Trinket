import TrinketContent
import TrinketCore

@MainActor
public extension PlayerSaveStore {
    func completeBattle(
        at destination: BattleCompletionDestination,
        party: (hero: Combatant, companion: Combatant),
        award: BattleRewardSettlement,
        loot: (materials: [ResourceAmount]?, item: InventoryItem?, result: BattleLootResult?),
        enemyEncounterLevel: Int?,
        earnedVoyageRewards: BattleRewardAward? = nil,
        makeContractOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> SaveTransactionResult<Void, EncounterCompletionFailure> {
        persistTransaction(logging: "Failed to complete battle encounter") { save, recordReceipt in
            let result: EncounterCompletion
            let (hero, companion) = party
            let (materialRewards, rewardItem, resolvedLoot) = loot
            let battleGold = award.award.goldFlow
            switch destination {
            case let .journey(stage):
                result = StageCompletion.complete(
                    stage, hero: hero, companion: companion, battleGold: battleGold, award: award,
                    materialRewards: materialRewards, rewardItem: rewardItem, loot: resolvedLoot, enemyEncounterLevel: enemyEncounterLevel,
                    in: GameContent.chapters, save: &save, recordReceipt: recordReceipt,
                )
            case let .spire(floor):
                result = SpireCompletion.complete(
                    floor: floor, hero: hero, companion: companion, battleGold: battleGold, award: award,
                    materialRewards: materialRewards, rewardItem: rewardItem, loot: resolvedLoot, enemyEncounterLevel: enemyEncounterLevel,
                    save: &save, recordReceipt: recordReceipt,
                )
            case let .labyrinth(nodeID, access):
                result = LabyrinthCompletion.complete(
                    nodeID: nodeID, hero: hero, companion: companion, battleGold: battleGold, award: award,
                    materialRewards: materialRewards, rewardItem: rewardItem, loot: resolvedLoot, enemyEncounterLevel: enemyEncounterLevel,
                    save: &save, access: access, recordReceipt: recordReceipt,
                )
            case let .contract(offerID):
                guard let resolvedLoot, let enemyEncounterLevel else { return .failure(.unavailable) }
                result = ContractsCompletion.complete(
                    offerID: offerID, hero: hero, companion: companion, encounterLevel: enemyEncounterLevel, loot: resolvedLoot,
                    battleGold: battleGold, award: award, save: &save, makeOffer: makeContractOffer, recordReceipt: recordReceipt,
                )
            case let .voyage(runID, nodeID, encounterLevel, access):
                guard let earnedVoyageRewards else { return .failure(.unavailable) }
                result = VoyageCompletion.completeBattle(
                    runID: runID, nodeID: nodeID, party: (hero, companion),
                    rewards: (award, earnedVoyageRewards, encounterLevel), save: &save, access: access, recordReceipt: recordReceipt,
                )
            }
            return result == .completed ? .success(()) : .failure(.unavailable)
        }
    }

    @discardableResult
    func claimStandaloneVictory(_ award: BattleRewardSettlement, hero: Combatant, companion: Combatant) -> Bool {
        persistBatch(logging: "Failed to persist battle rewards") { save, recordReceipt in
            VictoryRewardApplier.apply(award, hero: hero, companion: companion, save: &save, recordReceipt: recordReceipt)
        }
    }

    @discardableResult
    func claimDefeatExperience(_ award: BattleRewardSettlement, hero: Combatant, companion: Combatant) -> Bool {
        persistBatch(logging: "Failed to persist defeat experience") { save, recordReceipt in
            BattleExperienceReward.apply(award, hero: hero, companion: companion, save: &save, recordReceipt: recordReceipt)
        }
    }

    @discardableResult
    func completeJourneyStages(_ stages: [Stage], hero: Combatant, companion: Combatant, resetJourney: Bool = false) -> Bool {
        guard !stages.isEmpty else { return false }
        return persistBatch(logging: "Failed to persist stage completions") { save, recordReceipt in
            if resetJourney {
                save.journey = .initial
            }
            for stage in stages {
                StageCompletion.complete(
                    stage, hero: hero, companion: companion, in: GameContent.chapters, save: &save, recordReceipt: recordReceipt,
                )
            }
        }
    }
}
