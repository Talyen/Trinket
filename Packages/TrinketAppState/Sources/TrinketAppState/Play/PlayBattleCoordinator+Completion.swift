import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

extension PlayBattleCoordinator {
    func finishPresentation(configurationID: UUID) {
        guard case let .victory(pendingExit) = claimState,
              pendingExit.configurationID == configurationID else { return }
        guard battle.activeBattle?.id == configurationID else { return }
        claimState = .unclaimed
        restoreOrigin(pendingExit.origin)
        endBattle()
        pendingExit.onFinished()
    }

    func reset() {
        claimState = .unclaimed
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

    private func canClaimVictory(configurationID: UUID) -> Bool {
        switch claimState {
        case .unclaimed: true
        case let .defeat(claimedID): claimedID != configurationID
        case .victory: false
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
        playerSave.performSaveAction(key: SaveRetryKey.victory(configuration.id)) { [weak self] isRetry -> BattleCompletionResult in
            guard let self else { return .unavailable }
            // Fail closed while any presentation exit is pending. Same-ID calls
            // are duplicate claims; a different ID would overwrite the pending
            // onFinished and leak the first battle's exit.
            guard canClaimVictory(configurationID: configuration.id) else { return .unavailable }
            guard let run = activeRegistration(for: configuration) else { return .unavailable }
            let route = run.route
            // A settled award already includes material bonuses. With a supplied
            // settlement, validate against the launch plan's unadjusted materials.
            let baseMaterials = settlement == nil ? materialRewards : nil
            guard let resolved = settleRewards(
                configuration, battleGold: battleGold, materialRewards: baseMaterials,
                at: settlement?.inputs.productionDate ?? Date(),
            ) else { return .unavailable }
            guard settlement == nil || settlement == resolved else { return .staleSettlement(resolved) }
            let origin = route?.origin
            let earnedVoyageRewards: BattleRewardAward? = if case .voyage = route {
                run.launch.rewardPlan.resolve(
                    battleGold: resolved.award.goldFlow,
                    materials: baseMaterials,
                    includingCompletionBonus: false,
                )
            } else {
                nil
            }
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
            if result.didComplete {
                recordTalentProgressions(settlement ?? resolved, configuration: configuration)
                claimState = .victory(PendingExit(
                    configurationID: configuration.id, origin: origin,
                    onFinished: onFinished,
                ))
                if !run.launch.inputs.launch.stageRewardsAlreadyClaimed {
                    onClaimed()
                }
                if !defersPresentationExit || isRetry {
                    finishPresentation(configurationID: configuration.id)
                }
            }
            return result
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
    ) -> BattleCompletionResult {
        guard let run = activeRegistration(for: configuration),
              battle.resolvedDefeatProgress != nil else { return .unavailable }
        switch claimState {
        case .victory:
            return .unavailable
        case let .defeat(claimedID) where claimedID == configuration.id:
            return .completed
        case .unclaimed, .defeat:
            break
        }
        guard let resolved = settleDefeat(configuration, at: settlement.inputs.productionDate)
        else { return .unavailable }
        guard resolved == settlement else { return .staleSettlement(resolved) }
        switch playerSave.claimDefeatExperience(run.rewardClaim, award: resolved) {
        case .committed: break
        case .rejected: return .unavailable
        case .persistFailed: return .persistenceFailed
        }
        claimState = .defeat(configurationID: configuration.id)
        recordTalentProgressions(resolved, configuration: configuration)
        return .completed
    }

    func activeRegistration(for configuration: BattleRunConfiguration) -> PlayBattleRunRegistration? {
        guard battle.lifecyclePhase == .active, battle.activeBattle?.id == configuration.id,
              let activeRun, activeRun.launch.configuration.id == configuration.id,
              activeRun.rewardClaim.isCurrent(in: playerSave) else { return nil }
        return activeRun
    }

    func completeDefeat(
        _ configuration: BattleRunConfiguration,
        settlement: BattleRewardSettlement,
        action: BattleDefeatAction,
        onFinished: @escaping () -> Void,
    ) -> BattleCompletionResult {
        playerSave.performSaveAction(key: SaveRetryKey.defeat(configuration.id)) { [weak self] isRetry -> BattleCompletionResult in
            guard let self else { return .unavailable }
            guard let refreshed = isRetry ? settleDefeat(configuration, at: Date()) : settlement else { return .unavailable }

            let result = claimDefeat(configuration, settlement: refreshed)
            guard result.didComplete else { return result }
            switch action {
            case .retry:
                _ = requestRestart(onFinished: onFinished)
                return battle.activeBattle?.id != configuration.id ? .completed : .unavailable
            case .leave:
                endBattleReturningToOrigin(onFinished: onFinished)
                return .completed
            }
        }
    }
}
