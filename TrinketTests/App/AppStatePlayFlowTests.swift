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

    @Test func completeActiveBattleWithStageCompletesJourneyAndEndsBattle() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        let initialGold = state.roster.current.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 5)

        #expect(state.battle.activeBattle == nil)
        #expect(state.journey.current.activeStageID == "chapter-1-stage-2")
        #expect(state.journey.current.completedStageIDs.contains(stage.id))
        #expect(state.roster.current.gold > initialGold + 4)
    }

    @Test func completeActiveBattleIsIdempotentWhenContinueTappedTwice() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        let initialGold = state.roster.current.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 5)
        state.completeActiveBattle(configuration, battleEarnedGold: 5)

        #expect(state.battle.activeBattle == nil)
        #expect(state.journey.current.activeStageID == "chapter-1-stage-2")
        #expect(state.roster.current.gold == initialGold + 5 + stage.rewards.gold)
    }

    @Test func completeActiveBattleWithoutStageGrantsGoldOnly() throws {
        let state = try context.makeAppState()
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: state.roster.activeHero,
            pet: state.roster.activePet,
            enemy: enemy
        )
        state.battle.activeBattle = configuration
        let journeyBefore = state.journey.current
        let initialGold = state.roster.current.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 10)

        #expect(state.battle.activeBattle == nil)
        #expect(state.journey.current == journeyBefore)
        #expect(state.roster.current.gold == initialGold + 10)
    }

    @Test func completeActiveBattleWithoutStageIgnoresZeroGold() throws {
        let state = try context.makeAppState()
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: state.roster.activeHero,
            pet: state.roster.activePet,
            enemy: enemy
        )
        state.battle.activeBattle = configuration
        let initialGold = state.roster.current.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 0)

        #expect(state.roster.current.gold == initialGold)
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
        #expect(state.journey.current.activeStageID == stage.id)
    }
    #endif

    @Test func mapScrollFocusIDReturnsActiveStageWhenInProgress() throws {
        let state = try context.makeAppState()

        #expect(JourneyMapPresentation.scrollFocusID(for: .initial) == "chapter-1-stage-1")
    }

    @Test func mapScrollFocusIDReturnsNextChapterStageWhenChapterComplete() throws {
        _ = try context.makeAppState()
        var progress = JourneyProgressState.initial
        for stage in GameContent.chapters[0].stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        #expect(progress.activeStageID == "chapter-2-stage-1")
        #expect(JourneyMapPresentation.scrollFocusID(for: progress) == "chapter-2-stage-1")
    }

    @Test func resetGameplayProgressClearsBattleAndMapScroll() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        state.noteMapScrollFocus("chapter-1-stage-2")
        _ = state.completeStage(stage, hero: state.roster.activeHero, pet: state.roster.activePet)

        state.resetGameplayProgress()

        #expect(state.battle.activeBattle == nil)
        #expect(state.mapScrollStageID == nil)
        #expect(state.selectedTab == .play)
        #expect(state.journey.current.activeStageID == "chapter-1-stage-1")
        #expect(state.journey.current.completedStageIDs.isEmpty)
    }

    @Test func completeStageReturnsScrollFocusWithoutPersistingWhenSaveFails() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.roster.activeHero
        let pet = state.roster.activePet

        let scrollTarget = state.completeStage(stage, hero: hero, pet: pet)

        #expect(state.journey.current.activeStageID == "chapter-1-stage-2")
        #expect(state.journey.current.completedStageIDs.contains(stage.id))
        #expect(scrollTarget == "chapter-1-stage-2")
    }

    // MARK: - Launch landing

    @Test func launchLandingDefaultsToPlay() throws {
        let state = try context.makeAppState()

        #expect(state.selectedTab == .play)
    }

    @Test func launchLandingIgnoresPersistedShellTab() throws {
        context.userDefaults.set(
            AppTab.homestead.rawValue,
            forKey: PlayerShellSessionStore.legacySessionTabKey
        )

        let state = try context.makeAppState()

        #expect(state.selectedTab == .play)
    }

    @Test func launchLandingHonorsSelectedTabOverride() throws {
        context.userDefaults.set(
            AppTab.homestead.rawValue,
            forKey: PlayerShellSessionStore.legacySessionTabKey
        )

        let state = try context.makeAppState(arguments: ["-selectedTab", "options"])

        #expect(state.selectedTab == .options)
    }

    @Test func evaluateLaunchLandingForcesPlayWithoutOverride() throws {
        let state = try context.makeAppState()
        state.selectedTab = .homestead

        state.evaluateLaunchLanding()

        #expect(state.selectedTab == .play)
    }

    @Test func evaluateLaunchLandingKeepsLaunchOverrideTab() throws {
        let state = try context.makeAppState(arguments: ["-selectedTab", "options"])
        #expect(state.selectedTab == .options)

        state.evaluateLaunchLanding()

        #expect(state.selectedTab == .options)
    }

    @Test func legacyBattleResumeKeysDoNotRestoreBattle() throws {
        context.userDefaults.set(
            "chapter-1-stage-1",
            forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey
        )
        context.userDefaults.set(
            Date().timeIntervalSince1970,
            forKey: PlayerShellSessionStore.legacyActiveBattleSavedAtKey
        )

        let state = try context.makeAppState()

        #expect(state.battle.activeBattle == nil)
        #expect(state.selectedTab == .play)
    }

    @Test func completeStageUpdatesSessionMapScrollTarget() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        context.userDefaults.set(stage.id, forKey: PlayerShellSessionStore.legacyMapScrollStageIDKey)

        _ = state.completeStage(stage, hero: state.roster.activeHero, pet: state.roster.activePet)

        #expect(state.mapScrollStageID == "chapter-1-stage-2")
    }

    @Test func shouldRestoreMapScrollIgnoresCompletedStage() {
        var journey = JourneyProgressState.initial
        journey.complete(GameContent.chapters[0].stages[0], in: GameContent.chapters)

        #expect(!(AppState.shouldRestoreMapScroll("chapter-1-stage-1", journey: journey)))
        #expect(AppState.shouldRestoreMapScroll("chapter-1-stage-2", journey: journey))
    }

    @Test func launchScreenBattleStartsHardcodedStage() throws {
        let state = try context.makeAppState(arguments: ["-launch-screen", "battle"])

        let activeBattle = try #require(state.battle.activeBattle)
        #expect(activeBattle.stageID == "chapter-1-stage-1")
        #expect(state.selectedTab == .play)
    }

    @Test func resetGameplayProgressClearsBattleAndScroll() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        state.mapScrollStageID = "chapter-1-stage-2"

        state.resetGameplayProgress()

        #expect(state.battle.activeBattle == nil)
        #expect(state.mapScrollStageID == nil)
        #expect(state.selectedTab == .play)
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
        let state = try makeModesUnlockedStateForReturnTests()
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
        unlockLabyrinthForReturnTests(on: state)
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
        let state = try makeModesUnlockedStateForReturnTests()
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

    @Test func playLaunchDestinationMapsResumeTokens() {
        #expect(PlayLaunchDestination.returning(from: nil) == nil)
        #expect(
            PlayLaunchDestination.returning(from: .journey(stageID: "chapter-1-stage-1"))
                == .campaign
        )
        #expect(
            PlayLaunchDestination.returning(from: .aspect(aspectID: .ironVein, floor: 2))
                == .aspectClimb(.ironVein)
        )
        #expect(
            PlayLaunchDestination.returning(from: .labyrinth(nodeID: "node-1")) == .labyrinthMap
        )
    }

    private func makeModesUnlockedStateForReturnTests() throws -> AppState {
        try context.makeAppState(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-completed-stages",
            "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5"
        ])
    }

    private func attunePhysicalPartyForReturnTests(on state: AppState) throws {
        var roster = state.roster.current
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let lizard = try #require(GameContent.pets.first { $0.id == "lizard_scout" })
        roster.unlock(rogue)
        roster.unlock(lizard)
        roster.setActiveHero(rogue)
        roster.setActivePet(lizard)
        state.roster.current = roster
    }

    private func unlockLabyrinthForReturnTests(on state: AppState) {
        var journey = state.journey.current
        if let chapter = GameContent.chapters.first(where: { $0.id == "chapter-1" }) {
            for stage in chapter.stages {
                journey.completedStageIDs.insert(stage.id)
            }
        }
        state.journey.current = journey
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
