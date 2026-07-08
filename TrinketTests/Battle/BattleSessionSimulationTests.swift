import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import BattleEngine
@testable import Trinket

@MainActor
final class BattleSessionSimulationTests {
    @Test func advanceAutoTickShowsVictorySummaryWhenEnemyDefeated() throws {
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

        #expect(session.isShowingVictory)
        _ = try #require(session.victorySummary)
        #expect(!(session.isShowingDefeat))
    }

    @Test func advanceAutoTickCompletesImmediatelyWhenStageRewardsAlreadyClaimed() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: [])
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let stage = try #require(GameContent.chapters[0].stages.first)
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

        #expect(earnedGold == session.state?.earnedGold ?? 0)
        #expect(!(session.isShowingVictory))
        #expect(session.victorySummary == nil)
    }

    @Test func advanceAutoTickDoesNotAdvanceWhenBattlePaused() {
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

        #expect(session.state?.tickCount == tickBefore)
    }

    @Test func clearOutcomePresentationResetsVictoryAndDefeatFlagsWhenCleared() {
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

        #expect(!(session.isShowingVictory))
        #expect(!(session.isShowingDefeat))
        #expect(session.victorySummary == nil)
    }

    @Test func advanceOneStepAppendsNonMilestoneEventsWhenStepAdvances() {
        let session = BattleSessionTestSupport.makeConfiguredSession()

        _ = session.advanceOneStep()

        #expect(!(session.activeFeedbackEvents.isEmpty))
        #expect(session.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
    }

    @Test func advanceOneStepExcludesMilestonesWhenBattleEnds() {
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

        #expect(session.state?.isPartyDefeated == true)
        #expect(session.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
    }

    @Test func resetClearsFeedbackAndRebuildsStateWhenResetCalled() {
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
        #expect(!(session.activeFeedbackEvents.isEmpty))
        #expect(session.state?.health(of: session.state?.enemy ?? enemy) ?? 0 < 100)

        session.activeBattle = ActiveBattleConfigurationTestSupport.make(rngSeed: 0, hero: hero, pet: pet, enemy: enemy)

        #expect(session.activeFeedbackEvents.isEmpty)
        #expect(session.state?.health(of: session.state?.enemy ?? enemy) == 100)
        #expect(session.state?.health(of: session.state?.hero ?? hero) == hero.maxHealth)
    }

    @Test func removeFeedbackEventRemovesByIDWhenMatchingID() throws {
        let session = BattleSessionTestSupport.makeConfiguredSession()

        _ = session.advanceOneStep()
        let eventID = try #require(session.activeFeedbackEvents.first?.id)

        session.removeFeedbackEvent(eventID)

        #expect(session.activeFeedbackEvents.allSatisfy { $0.id != eventID })
    }

    @Test func pruneExpiredFeedbackRemovesEventsWhenPastDisplayDuration() throws {
        let session = BattleSessionTestSupport.makeConfiguredSession()

        _ = session.advanceOneStep()
        let eventID = try #require(session.activeFeedbackEvents.first?.id)
        let now = Date()

        session.pruneExpiredFeedback(at: now)
        #expect(session.activeFeedbackEvents.contains { $0.id == eventID })

        session.pruneExpiredFeedback(
            at: now.addingTimeInterval(CombatFeedbackTiming.displayDuration + 0.1)
        )
        #expect(session.activeFeedbackEvents.allSatisfy { $0.id != eventID })
    }

    @Test func outcomeReportsOngoingWhenBattleInProgress() {
        let session = BattleSessionTestSupport.makeConfiguredSession()

        _ = session.advanceOneStep()

        #expect(session.outcome == nil)
    }

    @Test func outcomeReportsVictoryWhenEnemyDefeated() {
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1, actionIntervalTicks: 100, abilities: [])
        let session = BattleSessionTestSupport.makeConfiguredSession(enemy: enemy)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        #expect(session.outcome == .victory)
    }

    @Test func outcomeReportsDefeatWhenPartyDefeated() {
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

        #expect(session.outcome == .defeat)
    }

    @Test func outcomeReportsVictoryWhenFaustianBargainDefeatsEnemyAndPetSurvives() {
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

        #expect(session.outcome == .victory)
        #expect(!(session.state?.isPartyDefeated ?? true))
        #expect(session.state?.isEnemyDefeated ?? false)
    }

    @Test func outcomeReportsVictoryWhenEnemyAndPartyDefeatedTogether() {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 0)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 0)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 0)
        let session = BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        #expect(session.state?.isPartyDefeated ?? false)
        #expect(session.state?.isEnemyDefeated ?? false)
        #expect(session.outcome == .victory)
    }

    @Test func resetPreservesEnemyModifiersWhenBattleReset() throws {
        let enemy = try #require(GameContent.enemy(matching: "skeleton"))
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

        #expect(
            session.state?.modifiers(for: enemy.combatant.id).controlResistancePercent ?? 0 > 0
        )
    }
}
