import Foundation
import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketFeatureSupport
import TrinketTestSupport
@testable import TrinketAppState
@testable import TrinketPersistence

@MainActor
struct AppStatePlayFlowTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func preparedJourneyBattleActivatesConfigurationAndState() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        state.journey.prepareBattle(for: stage)
        #expect(state.battle.activeBattle == nil)

        #expect(state.journey.startBattle(for: stage) == nil)

        #expect(state.battle.activeBattle?.runKey == PlayBattleOrigin.journey(stageID: stage.id).runKey)
        #expect(state.battle.state != nil)
    }

    @Test func completeActiveBattleWithStageCompletesJourneyIdempotently() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        let initialGold = state.playerSave.roster.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 5)

        #expect(state.battle.activeBattle == nil)
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-2")
        #expect(state.playerSave.journey.completedStageIDs.contains(stage.id))
        #expect(state.playerSave.roster.gold > initialGold + 4)

        let goldAfterFirstContinue = state.playerSave.roster.gold
        state.completeActiveBattle(configuration, battleEarnedGold: 5)

        #expect(state.battle.activeBattle == nil)
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-2")
        #expect(state.playerSave.roster.gold == goldAfterFirstContinue)
        let loot = BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: configuration.enemyEncounterLevel ?? 1,
            enemyIsBoss: false
        )
        #expect(state.playerSave.roster.gold == initialGold + 5 + loot.gold)
    }

    @Test func completeActiveBattleWithoutStageGrantsGoldOnly() throws {
        let state = try context.makePlaySession()
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: state.playerSave.roster.activeHero,
            companion: state.playerSave.roster.activeCompanion,
            enemy: enemy
        )
        state.battle.activeBattle = configuration
        let journeyBefore = state.playerSave.journey
        let initialGold = state.playerSave.roster.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 10)

        #expect(state.battle.activeBattle == nil)
        #expect(state.playerSave.journey == journeyBefore)
        #expect(state.playerSave.roster.gold == initialGold + 10)
    }

    #if DEBUG
    @Test(arguments: ["persist", "missing-stage", "missing-spire"] as [String])
    func completeActiveBattleKeepsBattleOpenOnFailure(mode: String) throws {
        switch mode {
        case "persist":
            let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
            let state = try context.makePlaySession(playerSave: playerSave)
            let stage = try #require(GameContent.chapters[0].stages.first)
            _ = state.journey.startBattle(for: stage)
            let configuration = try #require(state.battle.activeBattle)

            playerSave.forcesNextSaveFailure = true
            let didPersist = state.completeActiveBattle(configuration, battleEarnedGold: 0)

            #expect(!didPersist)
            #expect(state.battle.activeBattle != nil)
            #expect(state.playerSave.journey.activeStageID == stage.id)
        case "missing-stage":
            let state = try context.makePlaySession()
            let enemy = try #require(GameContent.enemies.first?.combatant)
            let configuration = try ActiveBattleConfigurationTestSupport.make(
                origin: .journey(stageID: "missing-stage-bug-hunt-audit"),
                rngSeed: 0,
                hero: state.playerSave.roster.activeHero,
                companion: state.playerSave.roster.activeCompanion,
                enemy: enemy
            )
            state.battle.activeBattle = configuration
            let goldBefore = state.playerSave.roster.gold

            let didPersist = state.completeActiveBattle(configuration, battleEarnedGold: 5)

            #expect(!didPersist)
            #expect(state.battle.activeBattle != nil)
            #expect(state.playerSave.roster.gold == goldBefore)
        case "missing-spire":
            let state = try context.makePlaySession()
            let enemy = try #require(GameContent.enemies.first?.combatant)
            let configuration = try ActiveBattleConfigurationTestSupport.make(
                origin: .spire(spireID: .ironVein, floor: 9999),
                rngSeed: 0,
                hero: state.playerSave.roster.activeHero,
                companion: state.playerSave.roster.activeCompanion,
                enemy: enemy
            )
            state.battle.activeBattle = configuration

            let didPersist = state.completeActiveBattle(configuration, battleEarnedGold: 5)

            #expect(!didPersist)
            #expect(state.battle.activeBattle != nil)
        default:
            Issue.record("Unexpected failure mode \(mode)")
        }
    }
    #endif

    @Test func unlockAllContentUnlocksRosterAndClearsBattle() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.play.journey.startBattle(for: stage)
        state.play.noteMapScrollFocus("chapter-1-stage-2")

        #expect(state.unlockAllContent())

        #expect(state.play.battle.activeBattle == nil)
        #expect(state.play.mapScrollStageID == nil)
        #expect(state.play.shellSession.selectedTab == .play)
    }

    @Test func shouldRestoreMapScrollIgnoresCompletedStage() {
        var journey = JourneyProgressState.initial
        journey.complete(GameContent.chapters[0].stages[0], in: GameContent.chapters)

        #expect(!(PlaySession.shouldRestoreMapScroll("chapter-1-stage-1", journey: journey)))
        #expect(PlaySession.shouldRestoreMapScroll("chapter-1-stage-2", journey: journey))
    }

    @Test(arguments: ["journey", "spire", "labyrinth"] as [String])
    func endBattleReturningToOriginQueuesExpectedDeepLink(origin: String) throws {
        switch origin {
        case "journey":
            let state = try context.makePlaySession()
            let stage = try #require(GameContent.chapters[0].stages.first)
            _ = state.journey.startBattle(for: stage)
            state.shellSession.selectedTab = .options

            state.endBattleReturningToOrigin()

            #expect(state.battle.activeBattle == nil)
            #expect(state.shellSession.selectedTab == .play)
            #expect(state.consumePendingDestination() == .campaign)
        case "spire":
            let state = try makeProgressedStateForReturnTests()
            try attunePhysicalPartyForReturnTests(on: state)

            let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
            #expect(state.spires.startBattle(for: floor) == nil)
            state.shellSession.selectedTab = .options

            state.endBattleReturningToOrigin()

            #expect(state.battle.activeBattle == nil)
            #expect(state.shellSession.selectedTab == .play)
            #expect(state.consumePendingDestination() == .spireClimb(.ironVein))
        case "labyrinth":
            let state = try context.makePlaySession(arguments: ["-reset-state"])
            _ = state.labyrinth.enter()
            let combatNodeID = try #require(firstReachableCombatNodeIDForReturnTests(in: state))
            #expect(state.labyrinth.startBattle(nodeID: combatNodeID) == nil)
            state.shellSession.selectedTab = .options

            state.endBattleReturningToOrigin()

            #expect(state.battle.activeBattle == nil)
            #expect(state.shellSession.selectedTab == .play)
            #expect(state.consumePendingDestination() == .labyrinthMap)
        default:
            Issue.record("Unexpected origin \(origin)")
        }
    }

    @Test func completeActiveBattleQueuesSpireReturnDestination() throws {
        let state = try makeProgressedStateForReturnTests()
        try attunePhysicalPartyForReturnTests(on: state)

        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        #expect(state.spires.startBattle(for: floor) == nil)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleEarnedGold: 1))
        #expect(state.consumePendingDestination() == .spireClimb(.ironVein))
    }

    @Test func completeActiveBattleGoldMatchesVictorySummaryWhenHomesteadBonusActive() throws {
        let state = try context.makePlaySession()
        var homestead = state.playerSave.homestead
        homestead.nodeTiers[.wishingWell] = 2
        state.playerSave.homestead = homestead

        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        // Loot All must pass raw mid-battle gold (summary.rawBattleEarnedGold), not the
        // homestead-adjusted display split (summary.battleGold).
        let rawBattleEarnedGold = 20
        let loot = BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: configuration.enemyEncounterLevel ?? 1,
            enemyIsBoss: false
        )
        let expectedTotal = StageCompletion.resolvedGoldReward(
            stageGold: loot.gold,
            battleEarnedGold: rawBattleEarnedGold,
            homestead: state.playerSave.homestead
        )
        let initialGold = state.playerSave.roster.gold

        #expect(state.completeActiveBattle(
            configuration,
            battleEarnedGold: rawBattleEarnedGold
        ))
        #expect(state.playerSave.roster.gold == initialGold + expectedTotal)
    }

    @Test func presentBattleLogShowsLogWithoutChangingTabs() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.journey.startBattle(for: stage)
        state.shellSession.selectedTab = .options

        state.battle.presentBattleLog()

        #expect(state.shellSession.selectedTab == .options)
        #expect(state.battle.isShowingBattleLog)
        #expect(state.battle.activeBattle != nil)
    }

    private func makeProgressedStateForReturnTests() throws -> PlaySession {
        try context.makePlaySession(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-completed-stages",
            "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5",
        ])
    }

    private func attunePhysicalPartyForReturnTests(on state: PlaySession) throws {
        var roster = state.playerSave.roster
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let lizard = try #require(GameContent.companions.first { $0.id == "lizard_scout" })
        roster.unlock(rogue)
        roster.unlock(lizard)
        roster.setActiveHero(rogue)
        roster.setActiveCompanion(lizard)
        state.playerSave.roster = roster
    }

    private func firstReachableCombatNodeIDForReturnTests(in state: PlaySession) -> String? {
        for _ in 0 ..< 24 {
            if let matchID = state.playerSave.labyrinth.reachableNodeIDs().first(where: { id in
                state.playerSave.labyrinth.node(id: id)?.type.isCombat == true
            }) {
                return matchID
            }
            guard let next = state.playerSave.labyrinth.reachableNodeIDs().first else { return nil }
            state.labyrinth.completeNode(nodeID: next)
        }
        return nil
    }
}
