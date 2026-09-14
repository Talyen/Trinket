import BattleEngine
import Foundation
import TrinketContent
import TrinketFeatureContracts
import TrinketPersistence

extension PlayBattleCompletion {
    func settleDefeat(
        _ configuration: BattleRunConfiguration,
        presentation: BattlePresentationContext,
        at date: Date,
    ) -> BattleRewardSettlement? {
        guard battle.activeBattle?.id == configuration.id,
              let progress = battle.resolvedDefeatProgress else { return nil }
        return presentation.rewardPlan.settleDefeat(
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
        presentation: BattlePresentationContext,
        settlement: BattleRewardSettlement,
    ) -> BattleCompletionResult {
        guard battle.lifecyclePhase == .active, battle.activeBattle?.id == configuration.id,
              battle.resolvedDefeatProgress != nil else { return .unavailable }
        if claimedDefeat?.configurationID == configuration.id {
            return .completed
        }
        guard let resolved = settleDefeat(configuration, presentation: presentation, at: settlement.inputs.productionDate)
        else { return .unavailable }
        guard resolved == settlement else { return .staleSettlement(resolved) }
        let didPersist = playerSave.persistBatch(logging: "Failed to persist defeat experience") { save in
            BattleExperienceReward.apply(
                resolved, hero: configuration.hero.combatant, companion: configuration.companion.combatant, save: &save,
            )
        }
        guard didPersist else { return .persistenceFailed }
        claimedDefeat = (configuration.id, resolved)
        for (id, before) in [
            configuration.hero.combatant.id: resolved.inputs.heroProgression,
            configuration.companion.combatant.id: resolved.inputs.companionProgression,
        ] where deferredDefeatTalentProgressions[id] == nil {
            deferredDefeatTalentProgressions[id] = before
        }
        return .completed
    }
}

public extension PlaySession {
    func settleDefeatRewards(_ configuration: BattleRunConfiguration) -> BattleRewardSettlement? {
        guard let presentation = battlePresentation(for: configuration) else { return nil }
        return battleCompletion.settleDefeat(configuration, presentation: presentation, at: Date())
    }

    func completeDefeat(
        _ configuration: BattleRunConfiguration,
        settlement: BattleRewardSettlement,
        action: BattleDefeatAction,
    ) -> BattleCompletionResult {
        guard let presentation = battlePresentation(for: configuration) else { return .unavailable }
        let result = battleCompletion.claimDefeat(configuration, presentation: presentation, settlement: settlement)
        guard result.didComplete else {
            if result == .persistenceFailed {
                playerSave.retrySaveAction(key: "defeat-\(configuration.id)") { [weak self] in
                    guard let self, battle.activeBattle?.id == configuration.id,
                          let refreshed = settleDefeatRewards(configuration) else { return }
                    _ = completeDefeat(configuration, settlement: refreshed, action: action)
                }
            }
            return result
        }
        switch action {
        case .retry:
            _ = restartActiveBattle()
            return battle.activeBattle?.id != configuration.id ? .completed : .unavailable
        case .leave:
            endBattleReturningToOrigin()
            return .completed
        }
    }
}
