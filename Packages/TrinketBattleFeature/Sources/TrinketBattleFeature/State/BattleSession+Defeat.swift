import BattleEngine
import Foundation
import TrinketContent
import TrinketFeatureContracts

extension BattleSession {
    public var resolvedDefeatProgress: BattleDefeatProgress? {
        guard outcome == .defeat else { return nil }
        return engineState?.defeatProgress
    }

    func makeDefeatSettlement(for configuration: BattleRunConfiguration) -> BattleRewardSettlement? {
        guard let progress = resolvedDefeatProgress, let context = presentationContext else { return nil }
        if let progression {
            return progression.settleDefeat(configuration)
        }
        let inputs = context.rewardInputs ?? Self.fallbackRewardInputs(for: configuration)
        return context.rewardPlan.settleDefeat(progress: progress, inputs: inputs)
    }

    #if DEBUG
    public func presentLaunchDefeat() {
        guard let configuration = activeBattle else { return }
        var state = BattleState(
            hero: configuration.hero.combatant, companion: configuration.companion.combatant,
            enemy: configuration.enemy,
            heroModifiers: configuration.hero.modifiers, companionModifiers: configuration.companion.modifiers,
            enemyModifiers: configuration.enemyModifiers,
            enemyFaction: configuration.enemyFaction, rngSeed: configuration.rngSeed,
            tracksLog: false,
        )
        for _ in 0 ..< 100 where !state.isBattleOver && state.defeatProgress.depletedFraction < 0.3 {
            if let card = PlayPolicy.greedy.preferredPlayableCard(in: state) {
                _ = try? state.playCard(cardID: card.id, rebuildLog: false)
            } else {
                _ = state.endTurn(rebuildLog: false)
            }
        }
        for _ in 0 ..< 100 where !state.isBattleOver {
            _ = state.endTurn(rebuildLog: false)
        }
        guard state.isPartyDefeated, !state.isEnemyDefeated else { return }
        cancelPendingAutoEnd()
        cancelTransitionPresentation()
        engineState = state
        commandState.transition(to: .outcome)
        clearCardCues()
        if let settlement = makeDefeatSettlement(for: configuration) {
            spectacle.outcomePresentation = .defeat(settlement)
        }
    }
    #endif

    func claimDefeat(configurationID: UUID, settlement: BattleRewardSettlement, action: BattleDefeatAction) -> Bool {
        guard let configuration = activeBattle, configuration.id == configurationID,
              resolvedDefeatProgress != nil, let progression else { return false }
        let result = progression.completeDefeat(configuration, settlement, action)
        guard activeBattle?.id == configurationID else { return result.didComplete }
        switch result {
        case .completed:
            return true
        case let .staleSettlement(updated):
            spectacle.outcomePresentation = .defeat(updated)
        case .persistenceFailed, .unavailable:
            break
        }
        return false
    }
}
