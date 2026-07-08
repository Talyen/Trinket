import Foundation
import Testing
import TrinketContent
import TrinketPersistence
import TrinketTestSupport
@testable import Trinket

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

    @Test func completeActiveBattleAdvancesJourneyWhenPersistFails() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makeAppState(playerSave: playerSave)
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)

        state.completeActiveBattle(configuration, battleEarnedGold: 0)

        #expect(state.battle.activeBattle == nil)
        #expect(state.journey.current.activeStageID == "chapter-1-stage-2")
    }

    @Test func mapScrollFocusIDReturnsActiveStageWhenInProgress() throws {
        let state = try context.makeAppState()

        #expect(JourneyMapPresentation.scrollFocusID(for: .initial) == "chapter-1-stage-1")
    }

    @Test func mapScrollFocusIDReturnsChapterGateWhenChapterComplete() throws {
        let state = try context.makeAppState()
        var progress = JourneyProgressState.initial
        for stage in GameContent.chapters[0].stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        #expect(progress.activeStageID == nil)
        #expect(
            JourneyMapPresentation.scrollFocusID(for: progress) == StageMapID.chapterGate(
                for: Chapter(
                    id: StageMapID.placeholderGate(afterChapterNumber: 2),
                    number: 2,
                    title: "",
                    theme: GameContent.chapters[0].theme,
                    stages: []
                )
            )
        )
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

    // MARK: - Session state restoration

    @Test func sessionTabRestored() throws {
        context.userDefaults.set(
            AppTab.homestead.rawValue,
            forKey: PlayerShellSessionStore.legacySessionTabKey
        )

        let state = try context.makeAppState()

        #expect(state.selectedTab == .homestead)
    }

    @Test func sessionTabOverriddenByEnv() throws {
        context.userDefaults.set(
            AppTab.homestead.rawValue,
            forKey: PlayerShellSessionStore.legacySessionTabKey
        )

        let state = try context.makeAppState(arguments: ["-selectedTab", "options"])

        #expect(state.selectedTab == .options)
    }

    @Test func sessionTabDefaultWhenNoSavedState() throws {
        let state = try context.makeAppState()

        #expect(state.selectedTab == .play)
    }

    @Test func selectedTabPersistsToSessionState() throws {
        let state = try context.makeAppState()
        state.selectedTab = .homestead
        #expect(state.selectedTab == .homestead)

        let state2 = try context.makeAppState()
        #expect(state2.selectedTab == .homestead)
    }

    @Test func sessionBattleRestoredAsResumeCardOnColdLaunch() throws {
        context.userDefaults.set(
            "chapter-1-stage-1",
            forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey
        )
        context.userDefaults.set(
            PlayerShellSessionStore.currentSchemaVersion,
            forKey: PlayerShellSessionStore.legacyActiveBattleSchemaVersionKey
        )
        context.userDefaults.set(
            Date().timeIntervalSince1970,
            forKey: PlayerShellSessionStore.legacyActiveBattleSavedAtKey
        )

        let state = try context.makeAppState()

        #expect(state.battle.activeBattle == nil)
        #expect(state.showResumeBattleCard)
        #expect(state.selectedTab == .play)
    }

    @Test func foregroundResumeWithinSeamlessWindowResumesBattle() throws {
        context.userDefaults.set(
            "chapter-1-stage-1",
            forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey
        )
        context.userDefaults.set(
            PlayerShellSessionStore.currentSchemaVersion,
            forKey: PlayerShellSessionStore.legacyActiveBattleSchemaVersionKey
        )
        context.userDefaults.set(
            Date().timeIntervalSince1970,
            forKey: PlayerShellSessionStore.legacyActiveBattleSavedAtKey
        )

        let state = try context.makeAppState()

        state.isColdLaunch = false
        state.shellSession.lastBackgroundedTime = Date().addingTimeInterval(-30)

        state.evaluateResumeRules()

        let activeBattle = try #require(state.battle.activeBattle)
        #expect(activeBattle.stageID == "chapter-1-stage-1")
    }

    @Test func foregroundResumeBeyondSeamlessWindowLandsOnPlayTabWithCard() throws {
        context.userDefaults.set(
            "chapter-1-stage-1",
            forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey
        )
        context.userDefaults.set(
            PlayerShellSessionStore.currentSchemaVersion,
            forKey: PlayerShellSessionStore.legacyActiveBattleSchemaVersionKey
        )
        context.userDefaults.set(
            Date().timeIntervalSince1970,
            forKey: PlayerShellSessionStore.legacyActiveBattleSavedAtKey
        )

        let state = try context.makeAppState()

        state.isColdLaunch = false
        state.shellSession.lastBackgroundedTime = Date().addingTimeInterval(-300)

        state.evaluateResumeRules()

        #expect(state.battle.activeBattle == nil)
        #expect(state.showResumeBattleCard)
        #expect(state.selectedTab == .play)
    }

    @Test func foregroundResumeBeyondSeamlessWindowCompletesPendingVictory() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        let initialGold = state.roster.current.gold

        state.battle.victorySummary = try BattleVictorySummary.make(
            configuration: configuration,
            state: #require(state.battle.state),
            homestead: state.homestead.current
        )
        state.battle.isShowingVictory = true
        state.isColdLaunch = false
        state.shellSession.lastBackgroundedTime = Date().addingTimeInterval(-300)

        state.evaluateResumeRules()

        #expect(state.battle.activeBattle == nil)
        #expect(!(state.showResumeBattleCard))
        #expect(state.journey.current.completedStageIDs.contains(stage.id))
        #expect(state.roster.current.gold > initialGold)
        #expect(state.selectedTab == .play)
    }

    @Test func foregroundResumeBeyondSeamlessWindowClearsOverlayOnMidFightDiscard() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        state.battle.presentCombatantDetail(CombatantCardDetail(combatant: state.roster.activeHero))
        #expect(state.battle.overlayCombatantDetail != nil)

        state.isColdLaunch = false
        state.shellSession.lastBackgroundedTime = Date().addingTimeInterval(-300)
        state.evaluateResumeRules()

        #expect(state.battle.activeBattle == nil)
        #expect(state.battle.overlayCombatantDetail == nil)
        #expect(state.showResumeBattleCard)
    }

    @Test func foregroundResumeBeyondExpiryWindowDiscardsSave() throws {
        context.userDefaults.set(
            "chapter-1-stage-1",
            forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey
        )
        context.userDefaults.set(
            PlayerShellSessionStore.currentSchemaVersion,
            forKey: PlayerShellSessionStore.legacyActiveBattleSchemaVersionKey
        )
        context.userDefaults.set(
            Date().addingTimeInterval(-86400 * 3).timeIntervalSince1970,
            forKey: PlayerShellSessionStore.legacyActiveBattleSavedAtKey
        )

        let state = try context.makeAppState()

        state.isColdLaunch = false
        state.shellSession.lastBackgroundedTime = Date().addingTimeInterval(-300)

        state.evaluateResumeRules()

        #expect(state.battle.activeBattle == nil)
        #expect(!state.showResumeBattleCard)
        #expect(state.activeBattleStageID == nil)
    }

    @Test func sessionBattleNotRestoredWhenRewardsAlreadyClaimed() throws {
        context.userDefaults.set(
            "chapter-1-stage-1",
            forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey
        )
        context.userDefaults.set(
            PlayerShellSessionStore.currentSchemaVersion,
            forKey: PlayerShellSessionStore.legacyActiveBattleSchemaVersionKey
        )
        context.userDefaults.set(
            Date().timeIntervalSince1970,
            forKey: PlayerShellSessionStore.legacyActiveBattleSavedAtKey
        )

        let state = try context.makeAppState(arguments: ["-completed-stages", "chapter-1-stage-1"])

        state.evaluateResumeRules()

        #expect(state.battle.activeBattle == nil)
        #expect(state.activeBattleStageID == nil)
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

    @Test func sessionBattleNotRestoredWhenLaunchScreenBattle() throws {
        context.userDefaults.set(
            "chapter-1-stage-1",
            forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey
        )

        let state = try context.makeAppState(arguments: ["-launch-screen", "battle"])

        // launch-screen battle uses the hardcoded stage, not the session one
        let activeBattle = try #require(state.battle.activeBattle)
        #expect(activeBattle.stageID == "chapter-1-stage-1")
    }

    @Test func sessionStaleStageIDIgnored() throws {
        context.userDefaults.set(
            "nonexistent-stage",
            forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey
        )

        let state = try context.makeAppState()
        state.evaluateResumeRules()

        #expect(state.battle.activeBattle == nil)
        #expect(state.activeBattleStageID == nil)
    }

    @Test func sessionBattleClearedOnEndBattle() throws {
        context.userDefaults.set(
            "chapter-1-stage-1",
            forKey: PlayerShellSessionStore.legacyActiveBattleStageIDKey
        )
        context.userDefaults.set(
            PlayerShellSessionStore.currentSchemaVersion,
            forKey: PlayerShellSessionStore.legacyActiveBattleSchemaVersionKey
        )
        context.userDefaults.set(
            Date().timeIntervalSince1970,
            forKey: PlayerShellSessionStore.legacyActiveBattleSavedAtKey
        )

        let state = try context.makeAppState()
        state.isColdLaunch = false
        state.shellSession.lastBackgroundedTime = Date().addingTimeInterval(-30)
        state.evaluateResumeRules()

        _ = try #require(state.battle.activeBattle)

        state.battle.endBattle()

        #expect(state.battle.activeBattle == nil)
        #expect(state.activeBattleStageID == nil)
    }

    @Test func resetGameplayProgressClearsSessionBattleState() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        state.mapScrollStageID = "chapter-1-stage-2"

        state.resetGameplayProgress()

        #expect(state.battle.activeBattle == nil)
        #expect(state.activeBattleStageID == nil)
        #expect(state.mapScrollStageID == nil)
    }

    @Test func sessionBattleStageIDSetOnStartBattle() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(state.activeBattleStageID == nil)

        _ = state.startBattle(for: stage)

        #expect(state.activeBattleStageID == "chapter-1-stage-1")
    }
}
