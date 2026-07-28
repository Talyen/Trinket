import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence
@testable import BattleEngine
@testable import TrinketAppState

@MainActor
struct BattleSessionAppIntegrationTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func startBattleConfiguresActiveBattleWhenStageIsValid() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)

        let message = appState.startBattle(for: stage)

        #expect(message == nil)
        let activeBattle = try #require(appState.battle.activeBattle)
        #expect(activeBattle.resumeToken == .journey(stageID: stage.id))
    }

    @Test func startBattleIgnoresRequestWhenBattleAlreadyActive() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        let firstBattleID = try #require(appState.battle.activeBattle?.id)

        let message = appState.startBattle(for: stage)

        #expect(message == nil)
        #expect(appState.battle.activeBattle?.id == firstBattleID)
    }

    @Test func restartBattleRefreshesProgressionFromRosterWhenRosterUpdated() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        #expect(appState.battle.activeBattle?.hero.progression.currentXP == 0)

        var updatedRoster = appState.roster
        updatedRoster.grantExperience(25, to: appState.roster.activeHero)
        appState.roster = updatedRoster
        appState.restartActiveBattle()

        #expect(appState.battle.activeBattle?.hero.progression.currentXP == 25)
    }

    @Test func startBattleReturnsMessageWhenEnemyMissing() throws {
        let appState = try context.makePlaySession()
        let brokenStage = Stage(
            id: "test-missing-enemy",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            encounter: .battle(enemyID: "missing-enemy"),
            rewards: .empty
        )

        let message = appState.startBattle(for: brokenStage)

        #expect(message?.title == "Encounter Missing")
        #expect(appState.battle.activeBattle == nil)
    }

    @Test func restartBattleRebuildsActiveConfigurationWhenBattleActive() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        let original = try #require(appState.battle.activeBattle)

        appState.restartActiveBattle()

        let restarted = try #require(appState.battle.activeBattle)
        #expect(restarted.resumeToken == original.resumeToken)
        #expect(restarted.hero.combatant.id == original.hero.combatant.id)
        #expect(restarted.id != original.id)
    }

    @Test func restartBattlePreservesLabyrinthRewardFields() throws {
        let appState = try context.makePlaySession(arguments: ["-reset-state"])
        _ = appState.enterLabyrinth()
        let combatNodeID = try #require(
            appState.labyrinth.reachableNodeIDs().first(where: { id in
                appState.labyrinth.node(id: id)?.type.isCombat == true
            })
        )
        #expect(appState.startLabyrinthBattle(nodeID: combatNodeID) == nil)
        let original = try #require(appState.battle.activeBattle)
        let effects = appState.labyrinth.effects(for: combatNodeID)
        #expect(original.universalModifiers.count == 1)
        for (keyword, amount) in effects.damageDealtBonus {
            #expect(original.hero.modifiers.damageDealtBonus(for: keyword) == amount)
            #expect(original.companion.modifiers.damageDealtBonus(for: keyword) == amount)
            #expect(original.enemyModifiers.damageDealtBonus(for: keyword) == amount)
        }

        appState.restartActiveBattle()

        let restarted = try #require(appState.battle.activeBattle)
        #expect(restarted.labyrinthNodeID == combatNodeID)
        #expect(restarted.universalModifiers == original.universalModifiers)
        #expect(restarted.pendingRewardItem == original.pendingRewardItem)
        #expect(restarted.rewardItems == original.rewardItems)
        #expect(restarted.id != original.id)
    }
}
