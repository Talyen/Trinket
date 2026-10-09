import SwiftUI
import Testing
import TrinketContent
import TrinketPersistenceTestSupport
@testable import TrinketAppState
@testable import TrinketBattleFeature
@testable import TrinketFeatureSupport
@testable import TrinketPersistence

extension BattleSessionAppIntegrationTests {
    @Test func `backgrounded collected reward flushes once and stale finish cannot end another battle`() throws {
        let app = try context.makeAppState(arguments: ["-reset-state"])
        let play = app.play
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(play.journey.startBattle(for: stage) == nil)
        let configuration = try #require(play.battle.activeBattle)
        let battle = try #require(context.lastBattle)
        battle.presentLaunchVictory()
        let summary = try #require(battle.spectacle.outcomePresentation.victorySummaryIfAvailable)
        let collection = RewardCollectionState()
        collection.perform(.collect(hapticsEnabled: false, claim: {
            battle.claimVictory(configurationID: configuration.id, summary: summary, defersPresentationExit: true)
        }, finish: {
            battle.finishVictoryPresentation(configurationID: configuration.id)
        }))
        #expect(collection.isCollected)
        let committed = play.playerSave.currentSave
        app.reconcileShellState(.scenePhaseChanged, scenePhase: .background)
        // RewardRevealExperienceScreen owns this notification-to-finish binding;
        // required smoke proves the actual view binding rather than a fake scene.
        collection.finish()
        #expect(play.battle.activeBattle == nil)
        #expect(play.shellSession.playPath == [.campaign])
        let reloaded = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        #expect(reloaded.currentSave == committed)
        app.reconcileShellState(.scenePhaseChanged, scenePhase: .active)
        #expect(play.journey.startBattle(for: stage) == nil)
        let next = try #require(play.battle.activeBattle?.id)
        collection.finish()
        battle.finishVictoryPresentation(configurationID: configuration.id)
        #expect(play.battle.activeBattle?.id == next)
        #expect(play.playerSave.currentSave == committed)
    }
}
