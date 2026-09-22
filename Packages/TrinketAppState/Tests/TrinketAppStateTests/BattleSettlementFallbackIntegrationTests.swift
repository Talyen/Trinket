import Foundation
import Testing
import TrinketContent
@testable import TrinketAppState
@testable import TrinketBattleFeature

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
        battle.progression = BattleProgression(
            presentation: progression.presentation,
            settleRewards: { _, _ in nil },
            settleDefeat: progression.settleDefeat,
            completeDefeat: progression.completeDefeat,
            finishPresentation: progression.finishPresentation,
            completeVictory: progression.completeVictory,
        )
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
