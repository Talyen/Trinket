import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts

public extension BattleSession {
    func connectProgression(to delegate: any BattleProgressionDelegate) {
        precondition(!hasConnectedProgression, "Battle progression may be connected only once")
        precondition(activeBattle == nil, "Connect battle progression before activation")
        hasConnectedProgression = true
        progression = delegate
    }

    func claimVictory(configurationID: UUID, summary: BattleVictorySummary, defersPresentationExit: Bool = false) -> Bool {
        guard let configuration = activeBattle, configuration.id == configurationID,
              let progression else { return false }
        let result = progression.completeActiveBattle(
            configuration, battleGold: summary.goldFlow, materialRewards: nil,
            settlement: summary.settlement, defersPresentationExit: defersPresentationExit,
        )
        applyCompletionResult(result, for: configuration)
        return result.didComplete
    }

    func finishVictoryPresentation(configurationID: UUID) {
        progression?.finishBattleRewardPresentation(configurationID: configurationID)
    }

    internal func deliverClaimedVictoryIfNeeded() {
        guard commandState.phase == .outcome,
              let configuration = activeBattle,
              presentationContext?.stageRewardsAlreadyClaimed == true,
              outcome == .victory,
              deliveredClaimedVictoryConfigurationID != configuration.id,
              let progression
        else { return }

        deliveredClaimedVictoryConfigurationID = configuration.id
        let result = progression.completeActiveBattle(
            configuration, battleGold: engineState?.goldFlow ?? .init(), materialRewards: nil,
            settlement: nil, defersPresentationExit: false,
        )
        applyCompletionResult(result, for: configuration)
    }

    private func applyCompletionResult(_ result: BattleCompletionResult, for configuration: BattleRunConfiguration) {
        guard activeBattle?.id == configuration.id else { return }
        switch result {
        case .completed:
            break
        case let .staleSettlement(settlement):
            guard let input = victoryInput else { return }
            presentVictory(BattleVictorySummary.make(
                configuration: configuration, settlement: settlement,
                heroName: input.heroName, companionName: input.companionName,
            ))
        case .unavailable:
            presentVictoryChromeForPersistRetry()
        case .persistenceFailed:
            presentVictoryChromeForPersistRetry()
        }
    }
}
