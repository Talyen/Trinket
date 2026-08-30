import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence
@testable import TrinketAppState
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionAppIntegrationTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func `start battle ignores request when battle already active`() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.journey.startBattle(for: stage)
        let firstBattleID = try #require(appState.battle.activeBattle?.id)

        let message = appState.journey.startBattle(for: stage)

        #expect(message == nil)
        #expect(appState.battle.activeBattle?.id == firstBattleID)
    }

    @Test func `restart battle refreshes progression from roster when roster updated`() throws {
        let appState = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.journey.startBattle(for: stage)

        #expect(appState.battle.activeBattle?.hero.progression.currentXP == 0)

        var updatedRoster = appState.playerSave.roster
        updatedRoster.grantExperience(3, to: appState.playerSave.roster.activeHero)
        appState.playerSave.roster = updatedRoster
        appState.restartActiveBattle()

        #expect(appState.battle.activeBattle?.hero.progression.currentXP == 3)
    }

    @Test func `start battle returns message when enemy missing`() throws {
        let appState = try context.makePlaySession()
        let brokenStage = Stage(
            id: "test-missing-enemy",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            encounter: .battle(enemyID: "missing-enemy"),
            rewards: .empty,
        )

        let message = appState.journey.startBattle(for: brokenStage)

        #expect(message?.title == "Encounter Missing")
        #expect(appState.battle.activeBattle == nil)
    }

    @Test func `restart battle rebuilds active configuration when battle active`() throws {
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

    @Test func `restart battle preserves labyrinth reward fields`() throws {
        let appState = try context.makePlaySession(arguments: ["-reset-state"])
        _ = appState.labyrinth.enter()
        let combatNodeID = try #require(
            LabyrinthTestSupport.firstReachableCombatNodeID(
                where: { node in
                    let effects = appState.playerSave.labyrinth.effects(for: node.id)
                    return !effects.damageDealtBonus.isEmpty
                        || !effects.damageTakenReduction.isEmpty
                        || effects.blockGainedBonus != 0
                        || effects.leechGainedPercent != 0
                },
                in: appState,
            ),
        )
        #expect(appState.labyrinth.startBattle(nodeID: combatNodeID) == nil)
        let original = try #require(appState.battle.activeBattle)
        let originalPresentation = try #require(appState.battlePresentation(for: original.runKey))
        let effects = appState.playerSave.labyrinth.effects(for: combatNodeID)
        let originalUniversalModifiers = appState.battleUniversalModifiers(for: original.runKey)
        #expect(originalUniversalModifiers.count == 1)
        for (keyword, amount) in effects.damageDealtBonus {
            #expect(original.hero.modifiers.damageDealtBonus(for: keyword) == 0)
            #expect(original.companion.modifiers.damageDealtBonus(for: keyword) == 0)
            #expect(original.enemyModifiers.damageDealtBonus(for: keyword) == amount)
        }

        appState.restartActiveBattle()

        let restarted = try #require(appState.battle.activeBattle)
        let restartedPresentation = try #require(appState.battlePresentation(for: restarted.runKey))
        #expect(restarted.runKey == PlayBattleOrigin.labyrinth(nodeID: combatNodeID).runKey)
        #expect(
            appState.battleUniversalModifiers(for: restarted.runKey) == originalUniversalModifiers,
        )
        #expect(restartedPresentation.pendingRewardItem == originalPresentation.pendingRewardItem)
        #expect(restartedPresentation.rewardItems == originalPresentation.rewardItems)
        #expect(restarted.id != original.id)
    }

    @Test func `clearing transient state removes the whole battle run record`() throws {
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

    @Test func `activating prepared battle keeps sibling prepared runs`() throws {
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
        let battle = try #require(context.lastBattle)

        #expect(appState.battlePresentation(for: firstRunKey) != nil)
        #expect(appState.battlePresentation(for: secondRunKey) != nil)

        _ = appState.journey.startBattle(for: secondStage)

        #expect(appState.battle.activeBattle?.runKey == secondRunKey)
        #expect(appState.battlePresentation(for: firstRunKey) != nil)
        #expect(appState.battlePresentation(for: secondRunKey) != nil)
        #expect(battle.hasPreparedRun(firstRunKey))
        #expect(!battle.hasPreparedRun(secondRunKey))
    }

    #if DEBUG
    @Test func `claimed victory persist failure presents victory chrome`() throws {
        let playerSave = try PlayerSaveStore(
            disableCloudSync: true,
            inMemoryOnly: true,
            persistSaveImmediately: true,
        )
        let battle = BattleSession(
            autoEndTurnDelay: 0,
            openingHandDrawStagger: 0,
            enemyAttackImpactDelayOverride: 0,
            outcomePresentationDelayOverride: 0,
            presentationEnvironment: .silent,
        )
        battle.partyCelebrateDelayOverride = .zero
        let state = try context.makePlaySession(playerSave: playerSave, battleRuntime: battle)
        let stage = try #require(GameContent.chapters[0].stages.first)
        try playerSave.performBatchMutation { save in
            save.journey.markRewardsClaimed(for: stage)
        }
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        let presentation = try #require(state.battlePresentation(for: configuration.runKey))
        battle.installPresentationContext(presentation)
        battle.installClaimedVictoryHandler(ownerID: UUID()) { configuration, earnedGold in
            playerSave.forcesNextSaveFailure = true
            let didPersist = state.completeActiveBattle(
                configuration,
                battleEarnedGold: max(earnedGold, 5),
            )
            if !didPersist {
                battle.presentVictoryChromeForPersistRetry()
            }
        }

        driveToVictory(battle)

        #expect(battle.outcome == .victory)
        #expect(battle.spectacle.isShowingVictory)
        #expect(battle.spectacle.victorySummary != nil)
        #expect(state.battle.activeBattle != nil)
    }
    #endif

    @MainActor
    private func driveToVictory(_ battle: BattleSession) {
        var steps = 0
        while battle.outcome == nil, steps < 200 {
            steps += 1
            if battle.pendingBoonOffer != nil {
                _ = battle.selectAutoBoon()
                continue
            }
            if battle.spectacle.activeCinematic != nil {
                battle.completeCinematicCollapse()
                continue
            }
            if let card = battle.hand.first(where: { battle.isCardPlayable($0) }) {
                _ = battle.playCard(cardID: card.id)
                continue
            }
            if battle.canEndTurn {
                battle.endTurn()
                continue
            }
            break
        }
        if battle.spectacle.activeCinematic != nil {
            battle.completeCinematicCollapse()
        }
        battle.handleOutcomeIfNeeded(at: .now)
    }
}
