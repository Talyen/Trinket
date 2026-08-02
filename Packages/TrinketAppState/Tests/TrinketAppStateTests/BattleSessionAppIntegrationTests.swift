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

        let message = appState.journey.startBattle(for: stage)

        #expect(message == nil)
        let activeBattle = try #require(appState.battle.activeBattle)
        #expect(activeBattle.runKey == PlayBattleOrigin.journey(stageID: stage.id).runKey)
    }

    @Test func startBattleIgnoresRequestWhenBattleAlreadyActive() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.journey.startBattle(for: stage)
        let firstBattleID = try #require(appState.battle.activeBattle?.id)

        let message = appState.journey.startBattle(for: stage)

        #expect(message == nil)
        #expect(appState.battle.activeBattle?.id == firstBattleID)
    }

    @Test func restartBattleRefreshesProgressionFromRosterWhenRosterUpdated() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.journey.startBattle(for: stage)

        #expect(appState.battle.activeBattle?.hero.progression.currentXP == 0)

        var updatedRoster = appState.playerSave.roster
        updatedRoster.grantExperience(25, to: appState.playerSave.roster.activeHero)
        appState.playerSave.roster = updatedRoster
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

        let message = appState.journey.startBattle(for: brokenStage)

        #expect(message?.title == "Encounter Missing")
        #expect(appState.battle.activeBattle == nil)
    }

    @Test func restartBattleRebuildsActiveConfigurationWhenBattleActive() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.journey.startBattle(for: stage)
        let original = try #require(appState.battle.activeBattle)

        appState.restartActiveBattle()

        let restarted = try #require(appState.battle.activeBattle)
        #expect(restarted.runKey == original.runKey)
        #expect(restarted.hero.combatant.id == original.hero.combatant.id)
        #expect(restarted.id != original.id)
    }

    @Test func restartBattlePreservesLabyrinthRewardFields() throws {
        let appState = try context.makePlaySession(arguments: ["-reset-state"])
        _ = appState.labyrinth.enter()
        let combatNodeID = try #require(
            appState.playerSave.labyrinth.reachableNodeIDs().first(where: { id in
                appState.playerSave.labyrinth.node(id: id)?.type.isCombat == true
            })
        )
        #expect(appState.labyrinth.startBattle(nodeID: combatNodeID) == nil)
        let original = try #require(appState.battle.activeBattle)
        let originalPresentation = try #require(appState.battlePresentation(for: original.runKey))
        let effects = appState.playerSave.labyrinth.effects(for: combatNodeID)
        let originalUniversalModifiers = appState.battleUniversalModifiers(for: original.runKey)
        #expect(originalUniversalModifiers.count == 1)
        for (keyword, amount) in effects.damageDealtBonus {
            #expect(original.hero.modifiers.damageDealtBonus(for: keyword) == amount)
            #expect(original.companion.modifiers.damageDealtBonus(for: keyword) == amount)
            #expect(original.enemyModifiers.damageDealtBonus(for: keyword) == amount)
        }

        appState.restartActiveBattle()

        let restarted = try #require(appState.battle.activeBattle)
        let restartedPresentation = try #require(appState.battlePresentation(for: restarted.runKey))
        #expect(restarted.runKey == PlayBattleOrigin.labyrinth(nodeID: combatNodeID).runKey)
        #expect(
            appState.battleUniversalModifiers(for: restarted.runKey) == originalUniversalModifiers
        )
        #expect(restartedPresentation.pendingRewardItem == originalPresentation.pendingRewardItem)
        #expect(restartedPresentation.rewardItems == originalPresentation.rewardItems)
        #expect(restarted.id != original.id)
    }

    @Test func clearingTransientStateRemovesTheWholeBattleRunRecord() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.journey.startBattle(for: stage)
        let runKey = try #require(appState.battle.activeBattle?.runKey)

        #expect(appState.route(for: runKey) != nil)
        #expect(appState.battlePresentation(for: runKey) != nil)

        appState.clearTransientState()

        #expect(appState.route(for: runKey) == nil)
        #expect(appState.battlePresentation(for: runKey) == nil)
        #expect(appState.battle.activeBattle == nil)
    }

    @Test func activatingPreparedBattleDropsRoutesForDiscardedPreparedRuns() throws {
        let appState = try context.makePlaySession()
        let combatStages = GameContent.chapters
            .flatMap(\.stages)
            .filter(\.encounter.isCombat)
        let firstStage = try #require(combatStages.first)
        let secondStage = try #require(combatStages.dropFirst().first)

        appState.journey.prepareBattle(for: firstStage)
        let firstRunKey = PlayBattleOrigin.journey(stageID: firstStage.id).runKey
        appState.journey.prepareBattle(for: secondStage)
        let secondRunKey = PlayBattleOrigin.journey(stageID: secondStage.id).runKey

        #expect(appState.battlePresentation(for: firstRunKey) != nil)
        #expect(appState.battlePresentation(for: secondRunKey) != nil)

        _ = appState.journey.startBattle(for: secondStage)

        #expect(appState.battle.activeBattle?.runKey == secondRunKey)
        #expect(appState.battlePresentation(for: firstRunKey) == nil)
        #expect(appState.battlePresentation(for: secondRunKey) != nil)
    }
}
