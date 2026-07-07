import TrinketContent
import TrinketCore
import TrinketPersistence
import XCTest
@testable import BattleEngine
@testable import Trinket

@MainActor
final class BattleSessionSimulationTests: XCTestCase {
    func testAdvanceAutoTickShowsVictorySummaryWhenEnemyDefeated() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let session = BattleSession()
        session.activeBattle = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)

        while session.outcome == nil {
            _ = session.advanceAutoTick(journey: .initial, homestead: .freshStart)
        }

        XCTAssertTrue(session.isShowingVictory)
        _ = try XCTUnwrap(session.victorySummary)
        XCTAssertFalse(session.isShowingDefeat)
    }

    func testAdvanceAutoTickCompletesImmediatelyWhenStageRewardsAlreadyClaimed() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        var journey = JourneyProgressState.initial
        journey.markRewardsClaimed(for: stage)
        let session = BattleSession()
        session.activeBattle = ActiveBattleConfigurationTestSupport.make(
            stageID: stage.id,
            rngSeed: 0,
            hero: hero,
            pet: pet,
            enemy: enemy
        )

        var earnedGold: Int?
        while session.outcome == nil {
            earnedGold = session.advanceAutoTick(journey: journey, homestead: .freshStart)
            if earnedGold != nil { break }
        }

        XCTAssertEqual(earnedGold, session.state?.earnedGold ?? 0)
        XCTAssertFalse(session.isShowingVictory)
        XCTAssertNil(session.victorySummary)
    }

    func testAdvanceAutoTickDoesNotAdvanceWhenBattlePaused() {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: [])
        let session = BattleSession()
        session.activeBattle = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)
        session.isPaused = true
        let tickBefore = session.state?.tickCount ?? 0

        _ = session.advanceAutoTick(journey: .initial, homestead: .freshStart)

        XCTAssertEqual(session.state?.tickCount, tickBefore)
    }

    func testClearOutcomePresentationResetsVictoryAndDefeatFlagsWhenCleared() {
        let session = BattleSession()
        session.isShowingVictory = true
        session.isShowingDefeat = true
        session.victorySummary = BattleVictorySummary(
            stageGold: 1,
            battleGold: 2,
            experience: 3,
            petExperience: 4,
            heroName: "Hero",
            petName: "Pet",
            itemNames: [],
            materialRewards: [],
            heroProgressionBefore: .initial,
            heroProgressionAfter: .initial,
            petProgressionBefore: .initial,
            petProgressionAfter: .initial
        )

        session.clearOutcomePresentation()

        XCTAssertFalse(session.isShowingVictory)
        XCTAssertFalse(session.isShowingDefeat)
        XCTAssertNil(session.victorySummary)
    }

    func testAdvanceOneStepAppendsNonMilestoneEventsWhenStepAdvances() {
        let session = BattleSessionTestSupport.makeConfiguredSession()

        _ = session.advanceOneStep()

        XCTAssertFalse(session.activeFeedbackEvents.isEmpty)
        XCTAssertTrue(session.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
    }

    func testAdvanceOneStepExcludesMilestonesWhenBattleEnds() {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 1, abilities: [])
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 1, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let session = BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        while !(session.state?.isBattleOver ?? true) {
            _ = session.advanceOneStep()
        }

        XCTAssertTrue(session.state?.isPartyDefeated == true)
        XCTAssertTrue(session.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
    }

    func testResetClearsFeedbackAndRebuildsStateWhenResetCalled() {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(
            id: "pet",
            role: .pet,
            actionIntervalTicks: 100,
            abilities: []
        )
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: []
        )
        let session = BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        _ = session.advanceOneStep()
        _ = session.advanceOneStep()
        XCTAssertFalse(session.activeFeedbackEvents.isEmpty)
        XCTAssertLessThan(session.state?.health(of: session.state?.enemy ?? enemy) ?? 0, 100)

        session.activeBattle = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)

        XCTAssertTrue(session.activeFeedbackEvents.isEmpty)
        XCTAssertEqual(session.state?.health(of: session.state?.enemy ?? enemy), 100)
        XCTAssertEqual(session.state?.health(of: session.state?.hero ?? hero), hero.maxHealth)
    }

    func testRemoveFeedbackEventRemovesByIDWhenMatchingID() throws {
        let session = BattleSessionTestSupport.makeConfiguredSession()

        _ = session.advanceOneStep()
        let eventID = try XCTUnwrap(session.activeFeedbackEvents.first?.id)

        session.removeFeedbackEvent(eventID)

        XCTAssertTrue(session.activeFeedbackEvents.allSatisfy { $0.id != eventID })
    }

    func testPruneExpiredFeedbackRemovesEventsWhenPastDisplayDuration() throws {
        let session = BattleSessionTestSupport.makeConfiguredSession()

        _ = session.advanceOneStep()
        let eventID = try XCTUnwrap(session.activeFeedbackEvents.first?.id)
        let now = Date()

        session.pruneExpiredFeedback(at: now)
        XCTAssertTrue(session.activeFeedbackEvents.contains { $0.id == eventID })

        session.pruneExpiredFeedback(
            at: now.addingTimeInterval(CombatFeedbackTiming.displayDuration + 0.1)
        )
        XCTAssertTrue(session.activeFeedbackEvents.allSatisfy { $0.id != eventID })
    }

    func testOutcomeReportsOngoingWhenBattleInProgress() {
        let session = BattleSessionTestSupport.makeConfiguredSession()

        _ = session.advanceOneStep()

        XCTAssertNil(session.outcome)
    }

    func testOutcomeReportsVictoryWhenEnemyDefeated() {
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let session = BattleSessionTestSupport.makeConfiguredSession(enemy: enemy)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        XCTAssertEqual(session.outcome, .victory)
    }

    func testOutcomeReportsDefeatWhenPartyDefeated() {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 1, abilities: [])
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 1, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let session = BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        XCTAssertEqual(session.outcome, .defeat)
    }

    func testOutcomeReportsVictoryWhenFaustianBargainDefeatsEnemyAndPetSurvives() {
        let hero = Combatant(
            id: "warlock",
            name: "Warlock",
            role: .hero,
            maxHealth: 3,
            actionIntervalTicks: 1,
            abilities: [.faustianBargain]
        )
        let pet = Combatant(
            id: "pet",
            name: "Pet",
            role: .pet,
            maxHealth: 20,
            actionIntervalTicks: 100,
            abilities: []
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 6,
            actionIntervalTicks: 100,
            abilities: []
        )
        let session = BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        XCTAssertEqual(session.outcome, .victory)
        XCTAssertFalse(session.state?.isPartyDefeated ?? true)
        XCTAssertTrue(session.state?.isEnemyDefeated ?? false)
    }

    func testOutcomeReportsVictoryWhenEnemyAndPartyDefeatedTogether() {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 0)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 0)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 0)
        let session = BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        XCTAssertTrue(session.state?.isPartyDefeated ?? false)
        XCTAssertTrue(session.state?.isEnemyDefeated ?? false)
        XCTAssertEqual(session.outcome, .victory)
    }

    func testResetPreservesEnemyModifiersWhenBattleReset() throws {
        let enemy = try XCTUnwrap(GameContent.enemy(matching: "skeleton"))
        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            pet: CombatantFixtures.combatant(id: "pet", role: .pet),
            enemy: enemy.combatant
        )
        let session = BattleSession()
        session.activeBattle = configuration

        session.activeBattle = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 1,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            pet: CombatantFixtures.combatant(id: "pet", role: .pet),
            enemy: enemy.combatant
        )

        XCTAssertGreaterThan(
            session.state?.modifiers(for: enemy.combatant.id).controlResistancePercent ?? 0,
            0
        )
    }
}
