import BattleEngine
import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
@testable import TrinketAppState
@testable import TrinketBattleFeature
@testable import TrinketPersistence

@MainActor
struct BattleSettlementFallbackIntegrationTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func `fallback victory display cannot grant a stale award`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(state.journey.startBattle(for: stage) == nil)
        let battle = try #require(state.battle as? BattleSession)
        let configuration = try #require(battle.activeBattle)
        let progression = try #require(battle.progression)
        let unavailable = UnavailableVictorySettlement(progression)
        battle.progression = unavailable
        defer { withExtendedLifetime(unavailable) {} }
        battle.presentLaunchVictory()
        let displayed = try #require(battle.spectacle.outcomePresentation.victorySummaryIfAvailable)
        try state.playerSave.performBatchMutation { save in save.roster.gold = 999 }

        #expect(!battle.claimVictory(configurationID: configuration.id, summary: displayed))
        #expect(!state.playerSave.journey.hasClaimedRewards(for: stage))
        let refreshed = try #require(battle.spectacle.outcomePresentation.victorySummaryIfAvailable)
        #expect(refreshed.settlement != displayed.settlement)
        #expect(battle.claimVictory(configurationID: configuration.id, summary: refreshed))
        #expect(state.playerSave.journey.hasClaimedRewards(for: stage))
    }
}

@MainActor
private final class UnavailableVictorySettlement: BattleProgressionDelegate {
    let underlying: any BattleProgressionDelegate
    init(_ underlying: any BattleProgressionDelegate) {
        self.underlying = underlying
    }

    func settleBattleRewards(
        _: BattleRunConfiguration,
        battleGold _: BattleGoldFlow,
        materialRewards _: [ResourceAmount]?,
        at _: Date?,
    ) -> BattleRewardSettlement? {
        nil
    }

    func settleDefeatRewards(_ configuration: BattleRunConfiguration, at date: Date?) -> BattleRewardSettlement? {
        underlying.settleDefeatRewards(configuration, at: date)
    }

    func completeActiveBattle(
        _ configuration: BattleRunConfiguration,
        battleGold: BattleGoldFlow,
        materialRewards: [ResourceAmount]?,
        settlement: BattleRewardSettlement?,
        defersPresentationExit: Bool,
    ) -> BattleCompletionResult {
        underlying.completeActiveBattle(
            configuration,
            battleGold: battleGold,
            materialRewards: materialRewards,
            settlement: settlement,
            defersPresentationExit: defersPresentationExit,
        )
    }

    func completeDefeat(
        _ configuration: BattleRunConfiguration,
        settlement: BattleRewardSettlement,
        action: BattleDefeatAction,
    ) -> BattleCompletionResult {
        underlying.completeDefeat(configuration, settlement: settlement, action: action)
    }

    func finishBattleRewardPresentation(configurationID: UUID) {
        underlying.finishBattleRewardPresentation(configurationID: configurationID)
    }
}
