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
        let session = BattleSession(outcomePresentationDelayOverride: 0)
        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(session.outcome == .victory)
        #expect(session.isShowingVictory)
        _ = try #require(session.victorySummary)
        #expect(!(session.isShowingDefeat))
    }

    @Test func victoryPresentationWaitsForTheConfiguredSpectacleHold() async throws {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(outcomePresentationDelayOverride: 0.05)
        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(session.outcome == .victory)
        #expect(session.victorySummary != nil)
        #expect(!session.isShowingVictory)
        #expect(!session.canRetreat)
        try await Task.sleep(for: .milliseconds(80))
        #expect(session.isShowingVictory)
        #expect(!session.canRetreat)
    }

    @Test func canRetreatIsFalseOnceOutcomeIsDecidedBeforeChromeAppears() throws {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(outcomePresentationDelayOverride: 0.05)
        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.canRetreat)
        BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(session.outcome == .victory)
        #expect(!session.isShowingVictory)
        #expect(!session.canRetreat)
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
            companion: party.companion,
            enemy: party.enemy
        )

        let earnedGold = BattleSessionTestSupport.driveUntilOutcome(session, journey: journey)

        #expect(earnedGold == session.state?.earnedGold ?? 0)
        #expect(!(session.isShowingVictory))
        #expect(session.victorySummary == nil)
    }

    @Test func endTurnDoesNothingWhenBattleAlreadyOver() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 0)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 0)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 0)
        let session = try BattleSessionTestSupport.makeConfiguredSession(hero: hero, companion: companion, enemy: enemy)
        #expect(session.canEndTurn == false)

        let result = session.endTurn(journey: .initial, homestead: .freshStart)

        #expect(result == nil)
    }

    @Test func clearOutcomePresentationResetsVictoryAndDefeatFlagsWhenCleared() {
        let session = BattleSession()
        session.isShowingVictory = true
        session.isShowingDefeat = true
        session.victorySummary = BattleVictorySummary(
            stageGold: 1,
            battleGold: 2,
            experience: 3,
            companionExperience: 4,
            heroName: "Hero",
            companionName: "Companion",
            heroArtworkName: nil,
            companionArtworkName: nil,
            rewardItems: [],
            materialRewards: [],
            heroProgressionBefore: .initial,
            heroProgressionAfter: .initial,
            companionProgressionBefore: .initial,
            companionProgressionAfter: .initial
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
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 1, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [.slash]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(hero: hero, companion: companion, enemy: enemy)

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
            companion: party.companion,
            enemy: party.enemy
        )
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        _ = session.playCard(cardID: card.id, journey: .initial, homestead: .freshStart)
        #expect(!(session.activeFeedbackEvents.isEmpty))
        #expect(session.state?.health(of: session.state?.enemy ?? party.enemy) ?? 0 < 100)

        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: BattleSessionTestSupport.deterministicBattleSeed,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.activeFeedbackEvents.isEmpty)
        #expect(session.state?.health(of: session.state?.enemy ?? party.enemy) == 100)
        #expect(session.state?.health(of: session.state?.hero ?? party.hero) == party.hero.maxHealth)
    }

    @Test func consolidatedFeedbackRemoveAndExpireClearsSources() throws {
        let session = BattleSession()
        let now = Date(timeIntervalSince1970: 100)
        session.recordFeedbackEvents(
            [
                feedbackEvent(id: 1, amount: 1),
                feedbackEvent(id: 2, amount: 2)
            ],
            at: now,
            stagger: 0
        )

        #expect(session.activeFeedbackItems.count == 1)
        #expect(session.activeFeedbackItems[0].sourceEventIDs == [1, 2])
        session.removeFeedbackEvent(2)
        #expect(session.activeFeedbackItems.isEmpty)
        #expect(session.activeFeedbackEvents.isEmpty)
        #expect(session.feedbackEventRecordedAt.isEmpty)

        session.recordFeedbackEvents(
            [
                feedbackEvent(id: 3, amount: 1),
                feedbackEvent(id: 4, amount: 2)
            ],
            at: now,
            stagger: 0
        )
        let item = try #require(session.activeFeedbackItems.first)
        session.pruneExpiredFeedback(at: item.expiresAt.addingTimeInterval(0.01))
        #expect(session.activeFeedbackItems.isEmpty)
        #expect(session.activeFeedbackEvents.isEmpty)
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

    @Test func resetPreservesEnemyModifiersWhenBattleReset() throws {
        let enemy = try #require(GameContent.enemy(matching: "skeleton"))
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: enemy.combatant
        )
        let session = BattleSession()
        session.activeBattle = configuration

        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 1,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
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

    @Test func autoEndTurnFiresOnlyWhenHandIsExhausted() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        #expect(session.hasPlayableCard)
        let tickWhilePlayable = try #require(session.state?.tickCount)

        session.considerAutoEndTurn(journey: .initial, homestead: .freshStart)
        try await Task.sleep(for: .milliseconds(30))
        #expect(session.state?.tickCount == tickWhilePlayable)
        #expect(session.canEndTurn)

        while let card = session.hand.first(where: { session.isCardPlayable($0) }) {
            let earned = session.playCard(
                cardID: card.id,
                journey: .initial,
                homestead: .freshStart
            )
            if earned != nil || session.outcome != nil {
                return
            }
        }

        #expect(session.canEndTurn)
        #expect(!session.hasPlayableCard)
        let tickBefore = try #require(session.state?.tickCount)

        try await waitForAutoEndTurn(session, after: tickBefore)

        #expect(session.state?.tickCount == tickBefore + 1)
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

    private func waitForAutoEndTurn(_ session: BattleSession, after tickBefore: Int) async throws {
        for _ in 0 ..< 40 {
            if session.state?.tickCount == tickBefore + 1 {
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Auto-end turn did not resolve within the test timeout")
    }

    private func feedbackEvent(id: Int, amount: Int) -> ActionEvent {
        ActionEvent(
            id: id,
            kind: .status,
            actorID: "hero",
            actorName: "Hero",
            abilityID: "bleed",
            abilityName: "Bleed",
            targetID: "enemy",
            targetName: "Enemy",
            amount: amount,
            keyword: .bleed
        )
    }
}
