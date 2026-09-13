import BattleEngine
import Foundation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts

@MainActor
struct BattleProgression {
    let presentation: (BattleRunConfiguration) -> BattlePresentationContext?
    let settleRewards: (BattleRunConfiguration, BattleGoldFlow) -> BattleRewardSettlement?
    let finishPresentation: (UUID) -> Void
    let completeVictory: (BattleRunConfiguration, BattleGoldFlow, BattleRewardSettlement?, Bool) -> BattleCompletionResult
}

public extension BattleSession {
    func configureProgression(
        presentation: @escaping (BattleRunConfiguration) -> BattlePresentationContext?,
        settleRewards: @escaping (BattleRunConfiguration, BattleGoldFlow) -> BattleRewardSettlement?,
        completeVictory: @escaping (BattleRunConfiguration, BattleGoldFlow, BattleRewardSettlement?, Bool) -> BattleCompletionResult,
        finishPresentation: @escaping (UUID) -> Void,
    ) {
        precondition(progression == nil)
        progression = BattleProgression(
            presentation: presentation,
            settleRewards: settleRewards,
            finishPresentation: finishPresentation,
            completeVictory: completeVictory,
        )
    }

    func claimVictory(configurationID: UUID, summary: BattleVictorySummary, defersPresentationExit: Bool = false) -> Bool {
        guard let configuration = activeBattle, configuration.id == configurationID,
              let progression else { return false }
        let result = progression.completeVictory(configuration, summary.goldFlow, summary.settlement, defersPresentationExit)
        applyCompletionResult(result, for: configuration)
        return result.didComplete
    }

    func finishVictoryPresentation(configurationID: UUID) {
        progression?.finishPresentation(configurationID)
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
        let result = progression.completeVictory(configuration, engineState?.goldFlow ?? .init(), nil, false)
        applyCompletionResult(result, for: configuration)
    }

    private func applyCompletionResult(_ result: BattleCompletionResult, for configuration: BattleRunConfiguration) {
        guard activeBattle?.id == configuration.id else { return }
        switch result {
        case .completed:
            break
        case let .staleSettlement(settlement):
            guard let input = victoryInput else { return }
            spectacle.outcomePresentation = .victory(BattleVictorySummary.make(
                configuration: configuration, settlement: settlement,
                heroName: input.heroName, companionName: input.companionName,
            ))
        case .unavailable:
            presentVictoryChromeForPersistRetry()
        case .persistenceFailed:
            presentVictoryChromeForPersistRetry()
            completionError = StageMapMessage(
                title: "Couldn't Save Progress",
                message: "Your victory was not saved. Stay on this screen and try Continue again.",
            )
        }
    }
}
