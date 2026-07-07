import TrinketContent
import TrinketPersistence
import Testing
@testable import Trinket

@Suite @MainActor
final class AppStatePlayFlowTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func completeActiveBattleWithStageCompletesJourneyAndEndsBattle() throws {
        let state = context.makeAppState()
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
        let state = context.makeAppState()
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
        let state = context.makeAppState()
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configuration = ActiveBattleConfigurationTestSupport.make(
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
        let state = context.makeAppState()
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configuration = ActiveBattleConfigurationTestSupport.make(
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
        let playerSave = SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = context.makeAppState(playerSave: playerSave)
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)

        state.completeActiveBattle(configuration, battleEarnedGold: 0)

        #expect(state.battle.activeBattle == nil)
        #expect(state.journey.current.activeStageID == "chapter-1-stage-2")
    }

    @Test func mapScrollFocusIDReturnsActiveStageWhenInProgress() {
        let state = context.makeAppState()

        #expect(JourneyMapPresentation.scrollFocusID(for: .initial) == "chapter-1-stage-1")
    }

    @Test func mapScrollFocusIDReturnsChapterGateWhenChapterComplete() {
        let state = context.makeAppState()
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
        let state = context.makeAppState()
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
        let state = context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let hero = state.roster.activeHero
        let pet = state.roster.activePet

        let scrollTarget = state.completeStage(stage, hero: hero, pet: pet)

        #expect(state.journey.current.activeStageID == "chapter-1-stage-2")
        #expect(state.journey.current.completedStageIDs.contains(stage.id))
        #expect(scrollTarget == "chapter-1-stage-2")
    }

    // MARK: - Session state restoration

    @Test func sessionTabRestored() {
        context.userDefaults.set(AppTab.homestead.rawValue, forKey: "session.selectedTab")

        let state = context.makeAppState()

        #expect(state.selectedTab == .homestead)
    }

    @Test func sessionTabOverriddenByEnv() {
        context.userDefaults.set(AppTab.homestead.rawValue, forKey: "session.selectedTab")

        let state = context.makeAppState(arguments: ["-selectedTab", "options"])

        #expect(state.selectedTab == .options)
    }

    @Test func sessionTabDefaultWhenNoSavedState() {
        let state = context.makeAppState()

        #expect(state.selectedTab == .play)
    }

    @Test func sessionBattleRestored() throws {
        context.userDefaults.set("chapter-1-stage-1", forKey: "session.activeBattleStageID")

        let state = context.makeAppState()

        let activeBattle = try #require(state.battle.activeBattle)
        #expect(activeBattle.stageID == "chapter-1-stage-1")
        #expect(state.selectedTab == .play)
    }

    @Test func sessionBattleNotRestoredWhenRewardsAlreadyClaimed() {
        context.userDefaults.set("chapter-1-stage-1", forKey: "session.activeBattleStageID")

        let state = context.makeAppState(arguments: ["-completed-stages", "chapter-1-stage-1"])

        #expect(state.battle.activeBattle == nil)
        #expect(state.activeBattleStageID == nil)
    }

    @Test func completeStageUpdatesSessionMapScrollTarget() throws {
        let state = context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        context.userDefaults.set(stage.id, forKey: "session.mapScrollStageID")

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
        context.userDefaults.set("chapter-1-stage-1", forKey: "session.activeBattleStageID")

        let state = context.makeAppState(arguments: ["-launch-screen", "battle"])

        // launch-screen battle uses the hardcoded stage, not the session one
        let activeBattle = try #require(state.battle.activeBattle)
        #expect(activeBattle.stageID == "chapter-1-stage-1")
    }

    @Test func sessionStaleStageIDIgnored() {
        context.userDefaults.set("nonexistent-stage", forKey: "session.activeBattleStageID")

        let state = context.makeAppState()

        #expect(state.battle.activeBattle == nil)
        #expect(state.activeBattleStageID == nil)
    }

    @Test func sessionBattleClearedOnEndBattle() throws {
        context.userDefaults.set("chapter-1-stage-1", forKey: "session.activeBattleStageID")

        let state = context.makeAppState()
        _ = try #require(state.battle.activeBattle)

        state.battle.endBattle()

        #expect(state.battle.activeBattle == nil)
        #expect(state.activeBattleStageID == nil)
    }

    @Test func resetGameplayProgressClearsSessionBattleState() throws {
        let state = context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.startBattle(for: stage)
        state.mapScrollStageID = "chapter-1-stage-2"

        state.resetGameplayProgress()

        #expect(state.battle.activeBattle == nil)
        #expect(state.activeBattleStageID == nil)
        #expect(state.mapScrollStageID == nil)
    }

    @Test func sessionBattleStageIDSetOnStartBattle() throws {
        let state = context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(state.activeBattleStageID == nil)

        _ = state.startBattle(for: stage)

        #expect(state.activeBattleStageID == "chapter-1-stage-1")
    }
}
