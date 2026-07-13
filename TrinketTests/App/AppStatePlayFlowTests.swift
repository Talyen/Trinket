import Foundation
import Testing
import TrinketContent
import TrinketTestSupport
@testable import Trinket
@testable import TrinketPersistence

@MainActor
struct AppStatePlayFlowTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func completeActiveBattleWithStageCompletesJourneyIdempotently() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        let initialGold = state.roster.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 5)

        #expect(state.battle.activeBattle == nil)
        #expect(state.journey.activeStageID == "chapter-1-stage-2")
        #expect(state.journey.completedStageIDs.contains(stage.id))
        #expect(state.roster.gold > initialGold + 4)

        let goldAfterFirstContinue = state.roster.gold
        state.completeActiveBattle(configuration, battleEarnedGold: 5)

        #expect(state.battle.activeBattle == nil)
        #expect(state.journey.activeStageID == "chapter-1-stage-2")
        #expect(state.roster.gold == goldAfterFirstContinue)
        #expect(state.roster.gold == initialGold + 5 + stage.rewards.gold)
    }

    @Test func completeActiveBattleWithoutStageGrantsGoldOnly() throws {
        let state = try context.makeAppState()
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: state.roster.activeHero,
            companion: state.roster.activeCompanion,
            enemy: enemy
        )
        state.battle.activeBattle = configuration
        let journeyBefore = state.journey
        let initialGold = state.roster.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 10)

        #expect(state.battle.activeBattle == nil)
        #expect(state.journey == journeyBefore)
        #expect(state.roster.gold == initialGold + 10)
    }

    #if DEBUG
    @Test func completeActiveBattleKeepsBattleOpenWhenPersistFails() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makeAppState(playerSave: playerSave)
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)

        playerSave.forcesNextSaveFailure = true
        let didPersist = state.completeActiveBattle(configuration, battleEarnedGold: 0)

        #expect(!didPersist)
        #expect(state.battle.activeBattle != nil)
        #expect(state.journey.activeStageID == stage.id)
    }
    #endif

    #if DEBUG
    @Test func unlockAllContentUnlocksRosterAndClearsBattle() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        state.noteMapScrollFocus("chapter-1-stage-2")

        #expect(state.unlockAllContent())

        #expect(state.battle.activeBattle == nil)
        #expect(state.mapScrollStageID == nil)
        #expect(state.selectedTab == .play)
        #expect(state.roster.unlockedHeroIDs == Set(GameContent.heroes.map(\.id)))
        #expect(state.roster.unlockedCompanionIDs == Set(GameContent.companions.map(\.id)))
        #expect(state.roster.highestHeroLevel == 20)
        #expect(state.roster.highestCompanionLevel == 20)
        #expect(state.roster.gold == PlayerRosterState.maxGoldBalance)
    }
    #endif

    @Test func shouldRestoreMapScrollIgnoresCompletedStage() {
        var journey = JourneyProgressState.initial
        journey.complete(GameContent.chapters[0].stages[0], in: GameContent.chapters)

        #expect(!(AppState.shouldRestoreMapScroll("chapter-1-stage-1", journey: journey)))
        #expect(AppState.shouldRestoreMapScroll("chapter-1-stage-2", journey: journey))
    }

    @Test func startBattleSetsInMemoryJourneyOrigin() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)

        _ = state.startBattle(for: stage)

        #expect(state.battle.activeBattle?.resumeToken == .journey(stageID: stage.id))
    }

    @Test func endBattleReturningToOriginFromJourneyQueuesCampaignDeepLink() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        state.selectedTab = .options

        state.endBattleReturningToOrigin()

        #expect(state.battle.activeBattle == nil)
        #expect(state.selectedTab == .play)
        #expect(state.consumePendingPlayDestination() == .campaign)
    }

    @Test func endBattleReturningToOriginFromAspectQueuesClimbDeepLink() throws {
        let state = try makeProgressedStateForReturnTests()
        try attunePhysicalPartyForReturnTests(on: state)

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        #expect(state.startAspectBattle(for: floor) == nil)
        state.selectedTab = .options

        state.endBattleReturningToOrigin()

        #expect(state.battle.activeBattle == nil)
        #expect(state.selectedTab == .play)
        #expect(state.consumePendingPlayDestination() == .aspectClimb(.ironVein))
    }

    @Test func endBattleReturningToOriginFromLabyrinthQueuesMapDeepLink() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        _ = state.enterLabyrinth()
        let combatNodeID = try #require(firstReachableCombatNodeIDForReturnTests(in: state))
        #expect(state.startLabyrinthBattle(nodeID: combatNodeID) == nil)
        state.selectedTab = .options

        state.endBattleReturningToOrigin()

        #expect(state.battle.activeBattle == nil)
        #expect(state.selectedTab == .play)
        #expect(state.consumePendingPlayDestination() == .labyrinthMap)
    }

    @Test func completeActiveBattleQueuesAspectReturnDestination() throws {
        let state = try makeProgressedStateForReturnTests()
        try attunePhysicalPartyForReturnTests(on: state)

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        #expect(state.startAspectBattle(for: floor) == nil)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleEarnedGold: 1))
        #expect(state.consumePendingPlayDestination() == .aspectClimb(.ironVein))
    }

    @Test func presentCombatLogShowsLogWithoutChangingTabs() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        state.selectedTab = .options

        state.presentCombatLog()

        #expect(state.selectedTab == .options)
        #expect(state.battle.isShowingBattleLog)
        #expect(state.battle.activeBattle != nil)
    }

    private func makeProgressedStateForReturnTests() throws -> AppState {
        try context.makeAppState(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-completed-stages",
            "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5"
        ])
    }

    private func attunePhysicalPartyForReturnTests(on state: AppState) throws {
        var roster = state.roster
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let lizard = try #require(GameContent.companions.first { $0.id == "lizard_scout" })
        roster.unlock(rogue)
        roster.unlock(lizard)
        roster.setActiveHero(rogue)
        roster.setActiveCompanion(lizard)
        state.roster = roster
    }

    private func firstReachableCombatNodeIDForReturnTests(in state: AppState) -> String? {
        for _ in 0 ..< 24 {
            if let matchID = state.labyrinth.reachableNodeIDs().first(where: { id in
                state.labyrinth.node(id: id)?.type.isCombat == true
            }) {
                return matchID
            }
            guard let next = state.labyrinth.reachableNodeIDs().first else { return nil }
            state.completeLabyrinthNode(nodeID: next)
        }
        return nil
    }
}
