import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
import TrinketTestSupport
@testable import BattleEngine
@testable import Trinket

@MainActor
struct BattleSessionSimulationTests {
    @Test func advanceAutoTickShowsVictorySummaryWhenEnemyDefeated() throws {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession()
        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: party.hero,
            pet: party.pet,
            enemy: party.enemy
        )

        while session.outcome == nil {
            _ = session.advanceAutoTick(journey: .initial, homestead: .freshStart)
        }

        #expect(session.isShowingVictory)
        _ = try #require(session.victorySummary)
        #expect(!(session.isShowingDefeat))
    }

    @Test func advanceAutoTickCompletesImmediatelyWhenStageRewardsAlreadyClaimed() throws {
        let party = BattlePartyFixtures.quickWinParty()
        let stage = try #require(GameContent.chapters[0].stages.first)
        var journey = JourneyProgressState.initial
        journey.markRewardsClaimed(for: stage)
        let session = BattleSession()
        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            stageID: stage.id,
            rngSeed: 0,
            hero: party.hero,
            pet: party.pet,
            enemy: party.enemy
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

    @Test func advanceAutoTickDoesNotAdvanceWhenBattlePaused() throws {
        let party = BattlePartyFixtures.quickWinParty(enemyMaxHealth: 100)
        let session = BattleSession()
        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: party.hero,
            pet: party.pet,
            enemy: party.enemy
        )
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

    @Test func advanceOneStepAppendsNonMilestoneEventsWhenStepAdvances() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()

        _ = session.advanceOneStep()

        #expect(!(session.activeFeedbackEvents.isEmpty))
        #expect(session.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
    }

    @Test func advanceOneStepExcludesMilestonesWhenBattleEnds() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 1, abilities: [])
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 1, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        while !(session.state?.isBattleOver ?? true) {
            _ = session.advanceOneStep()
        }

        #expect(session.state?.isPartyDefeated == true)
        #expect(session.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
    }

    @Test func resetClearsFeedbackAndRebuildsStateWhenResetCalled() throws {
        let party = BattlePartyFixtures.quickWinParty(enemyMaxHealth: 100)
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: party.hero,
            pet: party.pet,
            enemy: party.enemy
        )

        _ = session.advanceOneStep()
        _ = session.advanceOneStep()
        #expect(!(session.activeFeedbackEvents.isEmpty))
        #expect(session.state?.health(of: session.state?.enemy ?? party.enemy) ?? 0 < 100)

        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: party.hero,
            pet: party.pet,
            enemy: party.enemy
        )

        #expect(session.activeFeedbackEvents.isEmpty)
        #expect(session.state?.health(of: session.state?.enemy ?? party.enemy) == 100)
        #expect(session.state?.health(of: session.state?.hero ?? party.hero) == party.hero.maxHealth)
    }

    @Test func removeFeedbackEventRemovesByIDWhenMatchingID() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()

        _ = session.advanceOneStep()
        let eventID = try #require(session.activeFeedbackEvents.first?.id)

        session.removeFeedbackEvent(eventID)

        #expect(session.activeFeedbackEvents.allSatisfy { $0.id != eventID })
    }

    @Test func pruneExpiredFeedbackRemovesEventsWhenPastDisplayDuration() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()

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

    @Test func outcomeReportsOngoingWhenBattleInProgress() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()

        _ = session.advanceOneStep()

        #expect(session.outcome == nil)
    }

    @Test func outcomeReportsVictoryWhenEnemyDefeated() throws {
        let party = BattlePartyFixtures.quickWinParty()
        let session = try BattleSessionTestSupport.makeConfiguredSession(enemy: party.enemy)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        #expect(session.outcome == .victory)
    }

    @Test func outcomeReportsDefeatWhenPartyDefeated() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 1, abilities: [])
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 1, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        #expect(session.outcome == .defeat)
    }

    @Test func outcomeReportsVictoryWhenFaustianBargainDefeatsEnemyAndPetSurvives() throws {
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
        let session = try BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        while session.outcome == nil {
            _ = session.advanceOneStep()
        }

        #expect(session.outcome == .victory)
        #expect(!(session.state?.isPartyDefeated ?? true))
        #expect(session.state?.isEnemyDefeated ?? false)
    }

    @Test func outcomeReportsVictoryWhenEnemyAndPartyDefeatedTogether() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 0)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 0)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 0)
        let session = try BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        #expect(session.state?.isPartyDefeated ?? false)
        #expect(session.state?.isEnemyDefeated ?? false)
        #expect(session.outcome == .victory)
    }

    @Test func resetPreservesEnemyModifiersWhenBattleReset() throws {
        let enemy = try #require(GameContent.enemy(matching: "skeleton"))
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            pet: CombatantFixtures.combatant(id: "pet", role: .pet),
            enemy: enemy.combatant
        )
        let session = BattleSession()
        session.activeBattle = configuration

        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
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
