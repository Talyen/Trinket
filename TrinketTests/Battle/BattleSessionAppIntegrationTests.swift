import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import BattleEngine
@testable import Trinket

@MainActor
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
        let stage = try #require(GameContent.stages.first { $0.encounter.battleEnemyID != nil })

        appState.battle.setMusicPreview(for: stage)

        #expect(appState.battle.preview?.stageID == stage.id)
        #expect(appState.battle.preview?.enemyID == stage.encounter.battleEnemyID)
    }

    @Test func restartBattleRefreshesProgressionFromRosterWhenRosterUpdated() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        #expect(appState.battle.activeBattle?.hero.progression.currentXP == 0)

        var updatedRoster = appState.roster
        updatedRoster.grantExperience(25, to: appState.roster.activeHero)
        appState.roster = updatedRoster
        appState.restartActiveBattle()

        #expect(appState.battle.activeBattle?.hero.progression.currentXP == 25)
    }

    @Test func presentCombatantDetailSetsOverlayWithoutActiveBattle() throws {
        let appState = try context.makeAppState()
        let enemy = try #require(GameContent.enemy(matching: "skeleton")?.combatant)

        appState.battle.presentCombatantDetail(CombatantCardDetail(combatant: enemy))

        _ = try #require(appState.battle.overlayCombatantDetail)
        let activeState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = activeState.startBattle(for: stage)
        activeState.battle.presentCombatantDetail(CombatantCardDetail(combatant: activeState.roster.activeHero))
        _ = try #require(activeState.battle.overlayCombatantDetail)
        #expect(activeState.battle.canEndTurn)
    }

    @Test func endBattleClearsSessionStateWhenBattleEnds() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        appState.battle.preview = BattleMusicPreview(stageID: stage.id, enemyID: "skeleton")
        appState.battle.presentAbilityDetail(.slash)
        appState.battle.presentBattleLog()

        appState.battle.endBattle()

        #expect(appState.battle.activeBattle == nil)
        #expect(appState.battle.preview == nil)
        #expect(appState.battle.overlayCombatantDetail == nil)
        #expect(appState.battle.overlayAbilityDetail == nil)
        #expect(appState.battle.isShowingBattleLog == false)
        #expect(appState.battle.hand.isEmpty)
    }

    @Test func presentBattleLogSetsFlagAndSyncsLog() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)
        let card = try #require(appState.battle.hand.first(where: { appState.battle.isCardPlayable($0) }))
        _ = appState.battle.playCard(
            cardID: card.id,
            journey: appState.journey,
            homestead: appState.homestead
        )

        appState.battle.presentBattleLog()

        #expect(appState.battle.isShowingBattleLog)
        #expect(!(appState.battle.state?.log.isEmpty ?? true))

        appState.battle.clearBattleLog()
        #expect(appState.battle.isShowingBattleLog == false)
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

    @Test func presentAbilityDetailSetsOverlayWhenBattleActive() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = appState.startBattle(for: stage)

        appState.battle.presentAbilityDetail(.slash)

        #expect(appState.battle.overlayAbilityDetail?.id == Ability.slash.id)
        appState.battle.clearAbilityDetail()
        #expect(appState.battle.overlayAbilityDetail == nil)
    }

    @Test func musicPreviewClearsForActiveBattleAndNonBattleStage() throws {
        let appState = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        appState.battle.setMusicPreview(for: stage)
        _ = appState.startBattle(for: stage)

        appState.battle.setMusicPreview(for: stage)

        #expect(appState.battle.preview == nil)
        let shopStage = try #require(GameContent.stages.first { $0.encounter == .shop })

        let shopState = try context.makeAppState()
        shopState.battle.setMusicPreview(for: shopStage)

        #expect(shopState.battle.preview == nil)
    }
}
