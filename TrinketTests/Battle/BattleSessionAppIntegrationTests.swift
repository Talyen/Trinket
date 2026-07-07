import TrinketContent
import TrinketCore
import TrinketPersistence
import XCTest
@testable import BattleEngine
@testable import Trinket

@MainActor
final class BattleSessionAppIntegrationTests: AppTestCase {
    func testStartBattleConfiguresActiveBattleWhenStageIsValid() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)

        let message = appState.startBattle(for: stage)

        XCTAssertNil(message)
        let activeBattle = try XCTUnwrap(appState.battle.activeBattle)
        XCTAssertEqual(activeBattle.stageID, stage.id)
        XCTAssertNil(appState.battle.preview)
    }

    func testStartBattleIgnoresRequestWhenBattleAlreadyActive() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        let firstBattleID = try XCTUnwrap(appState.battle.activeBattle?.id)

        let message = appState.startBattle(for: stage)

        XCTAssertNil(message)
        XCTAssertEqual(appState.battle.activeBattle?.id, firstBattleID)
    }

    func testSetMusicPreviewUsesBattleEncounterWhenStageHasBattle() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)

        appState.battle.setMusicPreview(for: stage)

        XCTAssertEqual(appState.battle.preview?.stageID, stage.id)
        XCTAssertEqual(appState.battle.preview?.enemyID, "skeleton")
    }

    func testPauseForOverlayRestoresPreviousPauseStateWhenOverlayDismissed() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.isPaused = false

        appState.battle.pauseForOverlay()
        XCTAssertTrue(appState.battle.isPaused)

        appState.battle.restorePauseAfterOverlay()
        XCTAssertFalse(appState.battle.isPaused)
    }

    func testRestartBattleRefreshesProgressionFromRosterWhenRosterUpdated() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        XCTAssertEqual(appState.battle.activeBattle?.hero.progression.currentXP, 0)

        var updatedRoster = appState.roster.current
        updatedRoster.grantExperience(25, to: appState.roster.activeHero)
        appState.roster.current = updatedRoster
        appState.restartActiveBattle()

        XCTAssertEqual(appState.battle.activeBattle?.hero.progression.currentXP, 25)
    }

    func testPresentCombatantDetailWithoutActiveBattleDoesNotPauseSession() throws {
        let appState = makeAppState()
        let enemy = try XCTUnwrap(GameContent.enemy(matching: "skeleton")?.combatant)

        appState.battle.presentCombatantDetail(CombatantCardDetail(combatant: enemy))

        XCTAssertFalse(appState.battle.isPaused)
        _ = try XCTUnwrap(appState.battle.overlayCombatantDetail)
    }

    func testEndBattleClearsSessionStateWhenBattleEnds() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.isPaused = true
        appState.battle.preview = BattleMusicPreview(stageID: stage.id, enemyID: "skeleton")

        appState.battle.endBattle()

        XCTAssertNil(appState.battle.activeBattle)
        XCTAssertFalse(appState.battle.isPaused)
        XCTAssertNil(appState.battle.preview)
        XCTAssertNil(appState.battle.overlayCombatantDetail)
    }

    func testStartBattleReturnsMessageWhenEnemyMissing() {
        let appState = makeAppState()
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

        XCTAssertEqual(message?.title, "Encounter Missing")
        XCTAssertNil(appState.battle.activeBattle)
    }

    func testRestartBattleRebuildsActiveConfigurationWhenBattleActive() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        let original = try XCTUnwrap(appState.battle.activeBattle)

        appState.restartActiveBattle()

        let restarted = try XCTUnwrap(appState.battle.activeBattle)
        XCTAssertEqual(restarted.stageID, original.stageID)
        XCTAssertEqual(restarted.hero.combatant.id, original.hero.combatant.id)
        XCTAssertNotEqual(restarted.id, original.id)
    }

    func testPresentCombatantDetailPausesBattleAndSetsOverlayWhenBattleActive() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.isPaused = false
        let detail = CombatantCardDetail(combatant: appState.roster.activeHero)

        appState.battle.presentCombatantDetail(detail)

        XCTAssertTrue(appState.battle.isPaused)
        _ = try XCTUnwrap(appState.battle.overlayCombatantDetail)
    }

    func testRestorePauseAfterOverlayPreservesPriorPausedStateWhenAlreadyPaused() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.isPaused = true
        appState.battle.presentCombatantDetail(CombatantCardDetail(combatant: appState.roster.activeHero))

        appState.battle.restorePauseAfterOverlay()

        XCTAssertTrue(appState.battle.isPaused)
    }

    func testSetMusicPreviewClearsWhenBattleActive() throws {
        let appState = makeAppState()
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        appState.battle.setMusicPreview(for: stage)
        _ = appState.startBattle(for: stage)

        appState.battle.setMusicPreview(for: stage)

        XCTAssertNil(appState.battle.preview)
    }

    func testSetMusicPreviewClearsForNonBattleStage() throws {
        let appState = makeAppState()
        let shopStage = try XCTUnwrap(GameContent.chapters[0].stages.first { $0.encounter == .shop })

        appState.battle.setMusicPreview(for: shopStage)

        XCTAssertNil(appState.battle.preview)
    }
}
