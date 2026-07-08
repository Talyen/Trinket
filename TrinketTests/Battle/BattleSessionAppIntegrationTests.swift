import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import BattleEngine
@testable import Trinket

@Suite @MainActor
struct BattleSessionAppIntegrationTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func startBattleConfiguresActiveBattleWhenStageIsValid() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)

        let message = appState.startBattle(for: stage)

        #expect(message == nil)
        let activeBattle = try #require(appState.battle.activeBattle)
        #expect(activeBattle.stageID == stage.id)
        #expect(appState.battle.preview == nil)
    }

    @Test func startBattleIgnoresRequestWhenBattleAlreadyActive() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        let firstBattleID = try #require(appState.battle.activeBattle?.id)

        let message = appState.startBattle(for: stage)

        #expect(message == nil)
        #expect(appState.battle.activeBattle?.id == firstBattleID)
    }

    @Test func setMusicPreviewUsesBattleEncounterWhenStageHasBattle() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)

        appState.battle.setMusicPreview(for: stage)

        #expect(appState.battle.preview?.stageID == stage.id)
        #expect(appState.battle.preview?.enemyID == "skeleton")
    }

    @Test func pauseForOverlayRestoresPreviousPauseStateWhenOverlayDismissed() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.isPaused = false

        appState.battle.pauseForOverlay()
        #expect(appState.battle.isPaused)

        appState.battle.restorePauseAfterOverlay()
        #expect(!(appState.battle.isPaused))
    }

    @Test func restartBattleRefreshesProgressionFromRosterWhenRosterUpdated() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        #expect(appState.battle.activeBattle?.hero.progression.currentXP == 0)

        var updatedRoster = appState.roster.current
        updatedRoster.grantExperience(25, to: appState.roster.activeHero)
        appState.roster.current = updatedRoster
        appState.restartActiveBattle()

        #expect(appState.battle.activeBattle?.hero.progression.currentXP == 25)
    }

    @Test func presentCombatantDetailWithoutActiveBattleDoesNotPauseSession() throws {
        let appState = try context.makeAppState()
        let enemy = try #require(GameContent.enemy(matching: "skeleton")?.combatant)

        appState.battle.presentCombatantDetail(CombatantCardDetail(combatant: enemy))

        #expect(!(appState.battle.isPaused))
        _ = try #require(appState.battle.overlayCombatantDetail)
    }

    @Test func endBattleClearsSessionStateWhenBattleEnds() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.isPaused = true
        appState.battle.preview = BattleMusicPreview(stageID: stage.id, enemyID: "skeleton")

        appState.battle.endBattle()

        #expect(appState.battle.activeBattle == nil)
        #expect(!(appState.battle.isPaused))
        #expect(appState.battle.preview == nil)
        #expect(appState.battle.overlayCombatantDetail == nil)
    }

    @Test func startBattleReturnsMessageWhenEnemyMissing() throws {
        let appState = try context.makeAppState()
        let brokenStage = Stage(
            id: "test-missing-enemy",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            flavorText: "",
            encounter: .battle(enemyID: "missing-enemy"),
            rewards: .empty
        )

        let message = appState.startBattle(for: brokenStage)

        #expect(message?.title == "Encounter Missing")
        #expect(appState.battle.activeBattle == nil)
    }

    @Test func restartBattleRebuildsActiveConfigurationWhenBattleActive() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        let original = try #require(appState.battle.activeBattle)

        appState.restartActiveBattle()

        let restarted = try #require(appState.battle.activeBattle)
        #expect(restarted.stageID == original.stageID)
        #expect(restarted.hero.combatant.id == original.hero.combatant.id)
        #expect(restarted.id != original.id)
    }

    @Test func presentCombatantDetailPausesBattleAndSetsOverlayWhenBattleActive() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.isPaused = false
        let detail = CombatantCardDetail(combatant: appState.roster.activeHero)

        appState.battle.presentCombatantDetail(detail)

        #expect(appState.battle.isPaused)
        _ = try #require(appState.battle.overlayCombatantDetail)
    }

    @Test func restorePauseAfterOverlayPreservesPriorPausedStateWhenAlreadyPaused() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.isPaused = true
        appState.battle.presentCombatantDetail(CombatantCardDetail(combatant: appState.roster.activeHero))

        appState.battle.restorePauseAfterOverlay()

        #expect(appState.battle.isPaused)
    }

    @Test func setMusicPreviewClearsWhenBattleActive() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        appState.battle.setMusicPreview(for: stage)
        _ = appState.startBattle(for: stage)

        appState.battle.setMusicPreview(for: stage)

        #expect(appState.battle.preview == nil)
    }

    @Test func setMusicPreviewClearsForNonBattleStage() throws {
        let appState = try context.makeAppState()
        let shopStage = try #require(GameContent.chapters[0].stages.first { $0.encounter == .shop })

        appState.battle.setMusicPreview(for: shopStage)

        #expect(appState.battle.preview == nil)
    }
}
