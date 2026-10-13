import TrinketContent
import TrinketCore

@MainActor
public extension PlayerSaveStore {
    func prepareBattleRewardClaim(
        at destination: BattleCompletionDestination?, heroID: String, companionID: String,
    ) -> BattleRewardClaim {
        BattleRewardClaim(store: self, destination: destination, heroID: heroID, companionID: companionID)
    }

    func completeBattle(
        _ claim: BattleRewardClaim,
        award: BattleRewardSettlement,
        enemyEncounterLevel: Int?,
        earnedVoyageRewards: BattleRewardAward? = nil,
        makeContractOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> SaveTransactionResult<Void, EncounterCompletionFailure> {
        persistBattleReward(claim, award: award, logging: "Failed to complete battle encounter") { save, party, recordReceipt in
            let (hero, companion) = party
            guard let destination = claim.destination else {
                VictoryRewardApplier.apply(award, hero: hero, companion: companion, save: &save, recordReceipt: recordReceipt)
                return .success(())
            }
            guard let enemyEncounterLevel else { return .failure(.unavailable) }
            let result: EncounterCompletion
            let rewards = EncounterRewards.settled(award, encounterLevel: enemyEncounterLevel)
            switch destination {
            case let .journey(stage):
                result = StageCompletion.complete(
                    stage, hero: hero, companion: companion, rewards: rewards,
                    in: GameContent.chapters, save: &save, recordReceipt: recordReceipt,
                )
            case let .spire(floor):
                result = SpireCompletion.complete(
                    floor: floor, hero: hero, companion: companion, rewards: rewards,
                    save: &save, recordReceipt: recordReceipt,
                )
            case let .labyrinth(nodeID, access):
                result = LabyrinthCompletion.complete(
                    nodeID: nodeID, hero: hero, companion: companion, rewards: rewards,
                    save: &save, access: access, recordReceipt: recordReceipt,
                )
            case let .contract(offerID):
                result = ContractsCompletion.complete(
                    offerID: offerID, hero: hero, companion: companion,
                    rewards: rewards, save: &save, makeOffer: makeContractOffer, recordReceipt: recordReceipt,
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

    func claimDefeatExperience(
        _ claim: BattleRewardClaim, award: BattleRewardSettlement,
    ) -> SaveTransactionResult<Void, EncounterCompletionFailure> {
        persistBattleReward(claim, award: award, logging: "Failed to persist defeat experience") { save, party, recordReceipt in
            let (hero, companion) = party
            BattleExperienceReward.apply(award, hero: hero, companion: companion, save: &save, recordReceipt: recordReceipt)
            return .success(())
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

private extension PlayerSaveStore {
    func persistBattleReward(
        _ claim: BattleRewardClaim, award: BattleRewardSettlement, logging message: String,
        _ mutation: (inout PlayerSave, (hero: Combatant, companion: Combatant), (SaveEconomicReceipt) -> Void) -> Result<
            Void,
            EncounterCompletionFailure,
        >,
    ) -> SaveTransactionResult<Void, EncounterCompletionFailure> {
        guard claim.isCurrent(in: self), !claim.isConsumed else { return .rejected(.unavailable) }
        let candidate = SaveEconomicMutation(currentSave)
        guard let party = claim.party(in: candidate.save),
              award.inputs == RewardSettlementInputs(
                  save: candidate.save,
                  hero: party.hero,
                  companion: party.companion,
                  at: award.inputs.productionDate,
              )
        else { return .rejected(.unavailable) }
        switch mutation(&candidate.save, party, candidate.record) {
        case let .failure(error): return .rejected(error)
        case .success:
            do {
                try commit(candidate.save, accounting: .receipts(candidate.receipts))
                claim.consume()
                return .committed(())
            } catch {
                notePersistenceFailure(error, logging: message)
                return .persistFailed(PlayerSavePersistenceError.mapped(error))
            }
        }
    }
}
