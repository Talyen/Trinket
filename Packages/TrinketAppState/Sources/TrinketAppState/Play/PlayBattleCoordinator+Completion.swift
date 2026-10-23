import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

extension PlayBattleCoordinator {
    func finishPresentation(configurationID: UUID) {
        guard let activeBattle,
              activeBattle.registration.launch.configuration.id == configurationID,
              case let .victory(onFinished) = activeBattle.claimState,
              battle.activeBattle?.id == configurationID else { return }
        finishBattle(activeBattle, onFinished: onFinished)
    }

    func reset() {
        talentProgressionsBefore.removeAll()
    }

    func takeTalentProgressions() -> [String: CombatantProgression] {
        defer { talentProgressionsBefore.removeAll() }
        return talentProgressionsBefore
    }

    private func recordTalentProgressions(
        _ settlement: BattleRewardSettlement,
        configuration: BattleRunConfiguration,
    ) {
        // Retain the earliest baseline across Retry attempts, so Talent points
        // earned on a previous defeat remain visible when the player exits.
        for (id, before) in [
            configuration.hero.combatant.id: settlement.inputs.heroProgression,
            configuration.companion.combatant.id: settlement.inputs.companionProgression,
        ] where talentProgressionsBefore[id] == nil {
            talentProgressionsBefore[id] = before
        }
    }

    @discardableResult
    func completeActiveBattle(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards: [ResourceAmount]? = nil,
        settlement: BattleRewardSettlement? = nil,
        makeContractOffer: @escaping (ContractDifficulty, Set<String>, [RewardModifier]) -> ContractOffer = ContractGenerator.randomOffer,
        defersPresentationExit: Bool,
        onFinished: @escaping () -> Void,
        onClaimed: @escaping () -> Void,
    ) -> BattleCompletionResult {
        #if DEBUG
        print(
            "VICTORY_DIAG coordinator transition=\(runtimeTransition) currentClaim=\(activeRun?.rewardClaim.isCurrent(in: playerSave) == true) state=\(String(describing: activeBattle?.claimState))",
        )
        #endif
        guard runtimeTransition == .idle, let expectedBattle = activeBattle, isCurrent(expectedBattle),
              expectedBattle.registration.launch.configuration.id == configuration.id,
              case .unclaimed = expectedBattle.claimState else { return .unavailable }
        return playerSave.performSaveAction(key: SaveRetryKey.victory(configuration.id)) { [weak self] isRetry in
            guard let self, isCurrent(expectedBattle),
                  case .unclaimed = expectedBattle.claimState else { return SaveActionAttempt(.unavailable) }
            guard let run = activeRegistration(for: configuration) else { return SaveActionAttempt(.unavailable) }
            let route = run.route
            // A settled award already includes material bonuses. With a supplied
            // settlement, validate against the launch plan's unadjusted materials.
            let baseMaterials = settlement == nil ? materialRewards : nil
            guard let resolved = settleRewards(
                configuration, battleGold: battleGold, materialRewards: baseMaterials,
                at: settlement?.inputs.productionDate ?? Date(),
            ) else { return SaveActionAttempt(.unavailable) }
            guard settlement == nil || settlement == resolved else {
                #if DEBUG
                print(
                    "VICTORY_DIAG stale inputs=\(String(describing: settlement?.inputs)) resolved=\(resolved.inputs) awardMatches=\(settlement?.award == resolved.award)",
                )
                #endif
                return SaveActionAttempt(.staleSettlement(resolved))
            }
            let earnedVoyageRewards: BattleRewardAward? = if case .voyage = route {
                run.launch.rewardPlan.resolve(
                    battleGold: resolved.award.goldFlow,
                    materials: baseMaterials,
                    includingCompletionBonus: false,
                )
            } else {
                nil
            }
            expectedBattle.claimState = .claiming
            defer { expectedBattle.releaseClaim() }
            let committed = playerSave.completeBattle(
                run.rewardClaim, award: settlement ?? resolved,
                enemyEncounterLevel: configuration.enemyEncounterLevel,
                earnedVoyageRewards: earnedVoyageRewards, makeContractOffer: makeContractOffer,
            )
            let result: BattleCompletionResult = switch committed {
            case .committed: .completed
            case .rejected: .unavailable
            case .persistFailed: .persistenceFailed
            }
            if result.didComplete, isCurrent(expectedBattle) {
                recordTalentProgressions(settlement ?? resolved, configuration: configuration)
                expectedBattle.claimState = .victory(onFinished: onFinished)
                if !run.launch.inputs.launch.stageRewardsAlreadyClaimed {
                    onClaimed()
                }
                if isCurrent(expectedBattle), !defersPresentationExit || isRetry {
                    finishPresentation(configurationID: configuration.id)
                }
            }
            return SaveActionAttempt(result, failure: committed.persistenceError)
        }
    }

    func settleRewards(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards: [ResourceAmount]? = nil,
        at date: Date = Date(),
    ) -> BattleRewardSettlement? {
        guard let run = activeRegistration(for: configuration) else { return nil }
        return run.launch.rewardPlan.settle(
            battleGold: battleGold,
            inputs: RewardSettlementInputs(
                save: playerSave.currentSave, hero: configuration.hero.combatant, companion: configuration.companion.combatant, at: date,
            ),
            materials: materialRewards,
        )
    }

    func settleDefeat(
        _ configuration: BattleRunConfiguration,
        at date: Date,
    ) -> BattleRewardSettlement? {
        guard let run = activeRegistration(for: configuration),
              let progress = battle.resolvedDefeatProgress else { return nil }
        return run.launch.rewardPlan.settleDefeat(
            progress: progress,
            inputs: RewardSettlementInputs(
                save: playerSave.currentSave,
                hero: configuration.hero.combatant, companion: configuration.companion.combatant,
                at: date,
            ),
        )
    }

    func claimDefeat(
        _ configuration: BattleRunConfiguration,
        settlement: BattleRewardSettlement,
    ) -> SaveActionAttempt<BattleCompletionResult> {
        guard let run = activeRegistration(for: configuration),
              battle.resolvedDefeatProgress != nil else { return SaveActionAttempt(.unavailable) }
        guard let activeBattle else { return SaveActionAttempt(.unavailable) }
        switch activeBattle.claimState {
        case .claiming, .victory, .ending: return SaveActionAttempt(.unavailable)
        case .defeat: return SaveActionAttempt(.completed)
        case .unclaimed: break
        }
        guard let resolved = settleDefeat(configuration, at: settlement.inputs.productionDate)
        else { return SaveActionAttempt(.unavailable) }
        guard resolved == settlement else { return SaveActionAttempt(.staleSettlement(resolved)) }
        activeBattle.claimState = .claiming
        defer { activeBattle.releaseClaim() }
        switch playerSave.claimDefeatExperience(run.rewardClaim, award: resolved) {
        case .committed: break
        case .rejected: return SaveActionAttempt(.unavailable)
        case let .persistFailed(error): return SaveActionAttempt(.persistenceFailed, failure: error)
        }
        guard isCurrent(activeBattle) else { return SaveActionAttempt(.completed) }
        activeBattle.claimState = .defeat
        recordTalentProgressions(resolved, configuration: configuration)
        return SaveActionAttempt(.completed)
    }

    func activeRegistration(for configuration: BattleRunConfiguration) -> PlayBattleRunRegistration? {
        guard runtimeTransition == .idle, let activeBattle, isCurrent(activeBattle),
              activeBattle.registration.launch.configuration.id == configuration.id,
              activeBattle.registration.rewardClaim.isCurrent(in: playerSave) else { return nil }
        return activeBattle.registration
    }

    func completeDefeat(
        _ configuration: BattleRunConfiguration,
        settlement: BattleRewardSettlement,
        action: BattleDefeatAction,
        onFinished: @escaping () -> Void,
    ) -> BattleCompletionResult {
        guard runtimeTransition == .idle, let expectedBattle = activeBattle, isCurrent(expectedBattle),
              expectedBattle.registration.launch.configuration.id == configuration.id,
              expectedBattle.canRestart else { return .unavailable }
        return playerSave.performSaveAction(key: SaveRetryKey.defeat(configuration.id)) { [weak self] isRetry in
            guard let self, isCurrent(expectedBattle) else { return SaveActionAttempt(.unavailable) }
            guard let refreshed = isRetry ? settleDefeat(configuration, at: Date()) : settlement
            else { return SaveActionAttempt(.unavailable) }

            let result = claimDefeat(configuration, settlement: refreshed)
            guard result.value.didComplete, isCurrent(expectedBattle) else { return result }
            switch action {
            case .retry:
                _ = requestRestart(onFinished: onFinished)
                return SaveActionAttempt(battle.activeBattle?.id != configuration.id ? .completed : .unavailable)
            case .leave:
                endBattleReturningToOrigin(onFinished: onFinished)
                return SaveActionAttempt(.completed)
            }
        }
    }
}
