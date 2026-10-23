import Foundation
import Testing
import TrinketContent
import TrinketFeatureSupport
@testable import TrinketAppState
@testable import TrinketBattleFeature
@testable import TrinketPersistence

@MainActor
struct LabyrinthVictoryCompletionTests {
    @Test func `boss reward claim returns to the expanded map`() throws {
        let context = try AppTestContext()
        let play = try context.makePlaySession(arguments: ["-reset-state", "-seed-test-progress"])
        play.playerSave.installPerformanceFixtures(
            mysteryEvent: nil, wantsHomesteadBuild: false, wantsStrongParty: true,
            wantsTalentFixture: false, wantsTalentPoint: false, wantsLabyrinthScroll: false,
            labyrinthNodeType: .boss,
        )
        let boss = try #require(play.playerSave.labyrinth.nodes.values.first { $0.type == .boss && !$0.isCleared })
        #expect(play.labyrinth.startBattle(nodeID: boss.id) == nil)
        let configuration = try #require(play.battle.activeBattle)
        let battle = try #require(context.lastBattle)
        battle.presentLaunchVictory()
        let summary = try #require(battle.spectacle.outcomePresentation.victorySummaryIfAvailable)
        #expect(battle.claimVictory(configurationID: configuration.id, summary: summary, defersPresentationExit: true))
        #expect(play.playerSave.labyrinth.node(id: boss.id)?.isCleared == true)
        #expect(play.playerSave.labyrinth.currentFloorNumber == 2)
        battle.finishVictoryPresentation(configurationID: configuration.id)
        #expect(battle.activeBattle == nil)
        #expect(play.shellSession.playPath == [.explore, .labyrinthMap])
    }
}
