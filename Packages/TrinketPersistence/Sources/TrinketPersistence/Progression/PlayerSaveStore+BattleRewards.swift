import Foundation
import TrinketContent
import TrinketCore

@MainActor
public extension PlayerSaveStore {
    func prepareBattleRewardClaim(
        at destination: BattleCompletionDestination?, heroID: String, companionID: String, enemyID: String? = nil,
    ) -> BattleRewardClaim {
        BattleRewardClaim(store: self, destination: destination, heroID: heroID, companionID: companionID, enemyID: enemyID)
    }

    func completeBattle(
        _ claim: BattleRewardClaim,
        award: BattleRewardSettlement,
        enemyEncounterLevel: Int?,
        earnedVoyageRewards: BattleRewardAward? = nil,
        makeContractOffer: (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
    ) -> SaveTransactionResult<Void, EncounterCompletionFailure> {
        persistBattleReward(
            claim,
            award: award,
            victory: true,
            logging: "Failed to complete battle encounter",
        ) { save, party in
            let (hero, companion) = party
            guard let destination = claim.destination else {
                VictoryRewardApplier.apply(award, hero: hero, companion: companion, save: &save)
                return .success(())
            }
            guard let enemyEncounterLevel else { return .failure(.unavailable) }
            let result: EncounterCompletion
            let rewards = EncounterRewards.settled(award, encounterLevel: enemyEncounterLevel)
            switch destination {
            case let .journey(stage):
                result = StageCompletion.complete(
                    stage, hero: hero, companion: companion, rewards: rewards,
                    in: GameContent.chapters, save: &save,
                )
            case let .spire(floor):
                result = SpireCompletion.complete(
                    floor: floor, hero: hero, companion: companion, rewards: rewards,
                    save: &save,
                )
            case let .labyrinth(nodeID, access):
                result = LabyrinthCompletion.complete(
                    nodeID: nodeID, hero: hero, companion: companion, rewards: rewards,
                    save: &save, access: access,
                )
            case let .contract(offerID):
                result = ContractsCompletion.complete(
                    offerID: offerID, hero: hero, companion: companion,
                    rewards: rewards, save: &save, makeOffer: makeContractOffer,
                )
            case let .voyage(runID, nodeID, encounterLevel, access):
                guard let earnedVoyageRewards else { return .failure(.unavailable) }
                result = VoyageCompletion.completeBattle(
                    runID: runID, nodeID: nodeID, party: (hero, companion),
                    rewards: (award, earnedVoyageRewards, encounterLevel), save: &save, access: access,
                )
            }
            #if DEBUG
            NSLog("%@", "VICTORY_DIAG persistence destination=\(destination) completion=\(result)")
            #endif
            return result == .completed ? .success(()) : .failure(.unavailable)
        }
    }

    func claimDefeatExperience(
        _ claim: BattleRewardClaim, award: BattleRewardSettlement,
    ) -> SaveTransactionResult<Void, EncounterCompletionFailure> {
        persistBattleReward(claim, award: award, logging: "Failed to persist defeat experience") { save, party in
            let (hero, companion) = party
            BattleExperienceReward.apply(award, hero: hero, companion: companion, save: &save)
            return .success(())
        }
    }

    @discardableResult
    func completeJourneyStages(_ stages: [Stage], hero: Combatant, companion: Combatant, resetJourney: Bool = false) -> Bool {
        guard !stages.isEmpty else { return false }
        let candidate = makeMutation()
        if resetJourney {
            candidate.save.journey = .initial
        }
        for stage in stages {
            let _: Result<Void, Never> = candidate.resolve(claim: .journey(stage.id)) { save in
                StageCompletion.complete(stage, hero: hero, companion: companion, in: GameContent.chapters, save: &save)
                return .success(())
            }
        }
        let result: SaveTransactionResult<Void, Never> = finishTransaction(
            candidate, logging: "Failed to persist stage completions", result: .success(()),
        )
        if case .committed = result {
            return true
        }
        return false
    }
}

private extension PlayerSaveStore {
    func persistBattleReward(
        _ claim: BattleRewardClaim, award: BattleRewardSettlement, victory: Bool = false, logging message: String,
        _ mutation: (inout PlayerSave, (hero: Combatant, companion: Combatant)) -> Result<
            Void,
            EncounterCompletionFailure,
        >,
    ) -> SaveTransactionResult<Void, EncounterCompletionFailure> {
        #if DEBUG
        NSLog(
            "%@",
            "VICTORY_DIAG persistence current=\(claim.isCurrent(in: self)) consumed=\(claim.isConsumed) party=\(claim.party(in: currentSave) != nil)",
        )
        if let party = claim.party(in: currentSave) {
            NSLog(
                "%@",
                "VICTORY_DIAG persistence inputsMatch=\(award.inputs == RewardSettlementInputs(save: currentSave, hero: party.hero, companion: party.companion, at: award.inputs.productionDate))",
            )
        }
        #endif
        guard claim.isCurrent(in: self), !claim.isConsumed else { return .rejected(.unavailable) }
        let previousResearch = library.progress.completedResearchIDs
        let candidate = makeMutation()
        guard let party = claim.party(in: candidate.save),
              award.inputs == RewardSettlementInputs(
                  save: candidate.save, hero: party.hero, companion: party.companion,
                  at: award.inputs.productionDate,
              ) else { return .rejected(.unavailable) }
        let economicClaim = victory ? claim.destination?.economicClaim(in: candidate.save) : nil
        switch candidate.resolve(claim: economicClaim, { save in
            let result = mutation(&save, party)
            if case .success = result, victory, let enemyID = claim.enemyID {
                save.library.defeat(enemyID)
            }
            return result
        }) {
        case let .failure(error): return .rejected(error)
        case .success:
            do {
                try commit(candidate)
                claim.consume(completedResearchIDs: library.progress.completedResearchIDs.subtracting(previousResearch).sorted())
                return .committed(())
            } catch {
                notePersistenceFailure(error, logging: message)
                return .persistFailed(PlayerSavePersistenceError.mapped(error))
            }
        }
    }
}

private extension BattleCompletionDestination {
    func economicClaim(in save: PlayerSave) -> CloudEconomicAction.Claim {
        switch self {
        case let .journey(stage): .journey(stage.id)
        case let .spire(floor): .spire(id: floor.spireID.rawValue, floor: floor.floor)
        case let .labyrinth(nodeID, _): .labyrinth(seed: save.labyrinth.worldSeed, nodeID: nodeID)
        case let .contract(offerID): .contract(offerID)
        case let .voyage(runID, nodeID, _, _): .voyage(runID: runID, nodeID: nodeID)
        }
    }
}
