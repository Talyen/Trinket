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
    @Test func playCardShowsVictorySummaryWhenEnemyDefeated() throws {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession()
        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: party.hero,
            pet: party.pet,
            enemy: party.enemy
        )

        BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(session.isShowingVictory)
        _ = try #require(session.victorySummary)
        #expect(!(session.isShowingDefeat))
    }

    @Test func playCardCompletesImmediatelyWhenStageRewardsAlreadyClaimed() throws {
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

        let earnedGold = BattleSessionTestSupport.driveUntilOutcome(session, journey: journey)

        #expect(earnedGold == session.state?.earnedGold ?? 0)
        #expect(!(session.isShowingVictory))
        #expect(session.victorySummary == nil)
    }

    @Test func endTurnDoesNothingWhenBattleAlreadyOver() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 0)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 0)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 0)
        let session = try BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)
        #expect(session.canEndTurn == false)

        let result = session.endTurn(journey: .initial, homestead: .freshStart)

        #expect(result == nil)
        #expect(session.outcome == .victory)
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

    @Test func playCardAppendsNonMilestoneEventsWhenCardPlays() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        _ = session.playCard(cardID: card.id, journey: .initial, homestead: .freshStart)

        #expect(!(session.activeFeedbackEvents.isEmpty))
        #expect(session.activeFeedbackEvents.allSatisfy { $0.kind != .milestone })
    }

    @Test func endTurnExcludesMilestonesWhenBattleEnds() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 1, abilities: [])
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 1, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [.slash]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        while !(session.state?.isBattleOver ?? true) {
            _ = session.endTurn(journey: .initial, homestead: .freshStart)
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
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        _ = session.playCard(cardID: card.id, journey: .initial, homestead: .freshStart)
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
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        _ = session.playCard(cardID: card.id, journey: .initial, homestead: .freshStart)
        let eventID = try #require(session.activeFeedbackEvents.first?.id)

        session.removeFeedbackEvent(eventID)

        #expect(session.activeFeedbackEvents.allSatisfy { $0.id != eventID })
    }

    @Test func pruneExpiredFeedbackRemovesEventsWhenPastDisplayDuration() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        _ = session.playCard(cardID: card.id, journey: .initial, homestead: .freshStart)
        let item = try #require(session.activeFeedbackItems.first)
        let now = item.availableAt

        session.pruneExpiredFeedback(at: now)
        #expect(session.activeFeedbackItems.contains { $0.id == item.id })

        session.pruneExpiredFeedback(at: item.expiresAt.addingTimeInterval(0.1))
        #expect(session.activeFeedbackItems.allSatisfy { $0.id != item.id })
    }

    @Test func outcomeReportsOngoingWhenBattleInProgress() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        _ = session.playCard(cardID: card.id, journey: .initial, homestead: .freshStart)

        #expect(session.outcome == nil)
    }

    @Test func outcomeReportsVictoryWhenEnemyDefeated() throws {
        let party = BattlePartyFixtures.quickWinParty()
        let session = try BattleSessionTestSupport.makeConfiguredSession(enemy: party.enemy)

        BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(session.outcome == .victory)
    }

    @Test func outcomeReportsDefeatWhenPartyDefeated() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 1, abilities: [])
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 1, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [.slash]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(session.outcome == .defeat)
    }

    @Test func outcomeReportsVictoryWhenFaustianBargainDefeatsEnemyAndPetSurvives() throws {
        let hero = Combatant(
            id: "warlock",
            name: "Warlock",
            role: .hero,
            maxHealth: 3,
            abilities: [.faustianBargain]
        )
        let pet = Combatant(
            id: "pet",
            name: "Pet",
            role: .pet,
            maxHealth: 20,
            abilities: []
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 6,
            abilities: []
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(hero: hero, pet: pet, enemy: enemy)

        BattleSessionTestSupport.driveUntilOutcome(session)

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

    @Test func openingHandIsDealtAndCanEndTurnWhilePlayerTurn() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()

        #expect(!(session.hand.isEmpty))
        #expect(session.canEndTurn)
        #expect(session.hasPlayableCard)
    }

    @Test func autoEndsTurnAfterDelayWhenNoPlayableCardsRemain() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        session.considerAutoEndTurn(journey: .initial, homestead: .freshStart)

        while let card = session.hand.first(where: { session.isCardPlayable($0) }) {
            let earned = session.playCard(
                cardID: card.id,
                journey: .initial,
                homestead: .freshStart
            )
            if earned != nil || session.outcome != nil { return }
        }

        #expect(session.canEndTurn)
        #expect(!session.hasPlayableCard)
        let tickBefore = try #require(session.state?.tickCount)

        try await Task.sleep(for: .seconds(BattleSession.autoEndTurnDelay + 0.15))

        #expect(session.state?.tickCount == tickBefore + 1)
    }

    @Test func doesNotAutoEndTurnWhilePlayableCardsRemain() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        #expect(session.hasPlayableCard)
        let tickBefore = try #require(session.state?.tickCount)

        session.considerAutoEndTurn(journey: .initial, homestead: .freshStart)
        try await Task.sleep(for: .seconds(BattleSession.autoEndTurnDelay + 0.15))

        #expect(session.state?.tickCount == tickBefore)
        #expect(session.canEndTurn)
    }

    @Test func trimMemoryFootprintReleasesBattleLogProjection() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))
        _ = session.playCard(cardID: card.id, journey: .initial, homestead: .freshStart)
        session.syncLogForDisplay()
        #expect(!(session.state?.log.isEmpty ?? true))

        session.trimMemoryFootprint(releaseBattleLog: true)

        #expect(session.state?.log.isEmpty ?? false)
        #expect(!(session.state?.events.isEmpty ?? true))
    }
}
