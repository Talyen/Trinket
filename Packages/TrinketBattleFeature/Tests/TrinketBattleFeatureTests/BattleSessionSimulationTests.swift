import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionSimulationTests {
    @Test func victoryPresentationHoldsChromeAndLocksRetreatUntilConfiguredDelay() async throws {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(openingHandDrawStagger: 0, outcomePresentationDelayOverride: 0.05)
        session.partyCelebrateDelayOverride = 0
        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.canRetreat)
        BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(session.outcome == .victory)
        #expect(session.spectacle.victorySummary != nil)
        #expect(!session.spectacle.isShowingVictory)
        #expect(!session.canRetreat)
        let heroID = try #require(session.state?.hero.id)
        let companionID = try #require(session.state?.companion.id)
        #expect(session.feedback.hitReactionsByTargetID[heroID]?.kind == .celebrate)
        #expect(session.feedback.hitReactionsByTargetID[companionID]?.kind == .celebrate)
        let presentationTask = try #require(session.spectacle.pendingOutcomePresentationTask)
        await presentationTask.value
        #expect(session.spectacle.isShowingVictory)
        #expect(!session.canRetreat)
    }

    @Test func claimedStageRewardsAutoCompleteThenPersistRetryRestoresLootChrome() throws {
        let party = BattlePartyFixtures.quickWinParty()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let session = BattleSession(openingHandDrawStagger: 0, outcomePresentationDelayOverride: 0)
        session.partyCelebrateDelayOverride = 0
        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            resumeToken: .journey(stageID: stage.id),
            rngSeed: 0,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageRewardsAlreadyClaimed: true
        )

        let earnedGold = BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(earnedGold == session.state?.earnedGold ?? 0)
        #expect(!(session.spectacle.isShowingVictory))
        #expect(session.spectacle.victorySummary == nil)
        let heroID = try #require(session.state?.hero.id)
        let companionID = try #require(session.state?.companion.id)
        #expect(session.feedback.hitReactionsByTargetID[heroID]?.kind == .celebrate)
        #expect(session.feedback.hitReactionsByTargetID[companionID]?.kind == .celebrate)

        session.presentVictoryChromeForPersistRetry()

        #expect(session.spectacle.isShowingVictory)
        #expect(session.spectacle.victorySummary != nil)
        #expect(!session.canRetreat)
    }

    @Test func clearOutcomePresentationResetsVictoryAndDefeatFlagsWhenCleared() {
        let session = BattleSession(openingHandDrawStagger: 0)
        session.spectacle.isShowingVictory = true
        session.spectacle.isShowingDefeat = true
        session.spectacle.victorySummary = BattleVictorySummary(
            stageGold: 1,
            battleGold: 2,
            rawBattleEarnedGold: 2,
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

        #expect(!(session.spectacle.isShowingVictory))
        #expect(!(session.spectacle.isShowingDefeat))
        #expect(session.spectacle.victorySummary == nil)
    }

    @Test func playCardAppendsFeedbackItemsWhenCardPlays() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        _ = session.playCard(cardID: card.id)

        #expect(!(session.feedback.activeItems.isEmpty))
        let recordedIDs = Set(session.feedback.eventRecordedAt.keys)
        let milestoneIDs = Set((session.state?.events ?? []).filter { $0.kind == .milestone }.map(\.id))
        #expect(recordedIDs.isDisjoint(with: milestoneIDs))
    }

    @Test func playCardDistinguishesSuccessfulNonVictoryFromRejection() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        let committed = session.playCard(
            cardID: card.id
        )
        let rejected = session.playCard(
            cardID: Int.max
        )

        #expect(committed == .committed(earnedGold: nil))
        #expect(rejected == .rejected)
    }

    @Test func presentationProjectionTracksSimulationWithoutExposingLogStorage() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let configurationID = try #require(session.activeBattle?.id)
        let initialEnemyHealth = try #require(session.presentation.enemy?.health)
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        _ = session.playCard(cardID: card.id)

        let state = try #require(session.state)
        #expect(session.presentation.configurationID == configurationID)
        #expect(session.presentation.hand == state.hand.cards)
        #expect(session.presentation.enemy?.health == state.health(of: state.enemy))
        #expect((session.presentation.enemy?.health ?? initialEnemyHealth) <= initialEnemyHealth)

        session.endBattle()

        #expect(!session.presentation.isReady)
        #expect(session.presentation.hand.isEmpty)
    }

    @Test func endTurnExcludesMilestonesFromFeedbackWhenBattleEnds() throws {
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
            _ = session.endTurn()
        }

        #expect(session.state?.isPartyDefeated == true)
        let recordedIDs = Set(session.feedback.eventRecordedAt.keys)
        let milestoneIDs = Set((session.state?.events ?? []).filter { $0.kind == .milestone }.map(\.id))
        #expect(recordedIDs.isDisjoint(with: milestoneIDs))
        #expect(session.spectacle.deferredFeedbackEvents.allSatisfy { $0.kind != .milestone })
    }

    @Test func resetClearsFeedbackAndRebuildsStateWhenResetCalled() throws {
        let party = BattlePartyFixtures.quickWinParty(enemyMaxHealth: 100)
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        _ = session.playCard(cardID: card.id)
        #expect(!(session.feedback.activeItems.isEmpty))
        #expect(session.state?.health(of: session.state?.enemy ?? party.enemy) ?? 0 < 100)

        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: BattleSessionTestSupport.deterministicBattleSeed,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.feedback.activeItems.isEmpty)
        #expect(session.state?.health(of: session.state?.enemy ?? party.enemy) == 100)
        #expect(session.state?.health(of: session.state?.hero ?? party.hero) == party.hero.maxHealth)
    }

    @Test func consolidatedFeedbackRemoveAndExpireClearsSources() throws {
        let session = BattleSession(openingHandDrawStagger: 0)
        let now = Date(timeIntervalSince1970: 100)
        session.feedback.record(
            [
                feedbackEvent(id: 1, amount: 1),
                feedbackEvent(id: 2, amount: 2),
            ],
            at: now
        )

        #expect(session.feedback.activeItems.count == 1)
        #expect(session.feedback.activeItems[0].sourceEventIDs == [1, 2])
        session.feedback.removeEvent(2)
        #expect(session.feedback.activeItems.isEmpty)
        #expect(session.feedback.eventRecordedAt.isEmpty)

        session.feedback.record(
            [
                feedbackEvent(id: 3, amount: 1),
                feedbackEvent(id: 4, amount: 2),
            ],
            at: now
        )
        let item = try #require(session.feedback.activeItems.first)
        session.feedback.pruneExpired(at: item.availableAt)
        #expect(session.feedback.activeItems.contains { $0.id == item.id })
        session.feedback.pruneExpired(at: item.expiresAt.addingTimeInterval(0.01))
        #expect(session.feedback.activeItems.isEmpty)
        #expect(session.feedback.eventRecordedAt.isEmpty)
    }

    @Test func staleFeedbackBridgeOwnerCannotUninstallCurrentHandler() {
        let session = BattleSession(openingHandDrawStagger: 0)
        let staleOwnerID = UUID()
        let currentOwnerID = UUID()
        var receivedUpdates: [CombatFeedbackUpdate] = []

        session.feedback.installBridge(ownerID: staleOwnerID) { _ in }
        session.feedback.installBridge(ownerID: currentOwnerID) { update in
            receivedUpdates.append(update)
        }
        session.feedback.uninstallBridge(ownerID: staleOwnerID)

        session.feedback.record([feedbackEvent(id: 1, amount: 2)])
        #expect(receivedUpdates.count == 1)

        session.feedback.uninstallBridge(ownerID: currentOwnerID)
        session.feedback.record([feedbackEvent(id: 2, amount: 3)])
        #expect(receivedUpdates.count == 1)
    }

    @Test func currentFeedbackBridgeUninstallRestoresPreviousHandler() {
        let session = BattleSession(openingHandDrawStagger: 0)
        let survivingOwnerID = UUID()
        let departingOwnerID = UUID()
        var receivedUpdates: [CombatFeedbackUpdate] = []

        session.feedback.installBridge(ownerID: survivingOwnerID) { update in
            receivedUpdates.append(update)
        }
        session.feedback.installBridge(ownerID: departingOwnerID) { _ in }
        session.feedback.uninstallBridge(ownerID: departingOwnerID)

        session.feedback.record([feedbackEvent(id: 1, amount: 2)])
        #expect(receivedUpdates.count == 1)
    }

    @Test func feedbackVisualsUseIndependentPerTargetStreams() {
        let session = BattleSession(openingHandDrawStagger: 0)
        let now = Date(timeIntervalSince1970: 100)
        session.feedback.record(
            [
                feedbackEvent(id: 1, amount: 1, keyword: .bleed),
                feedbackEvent(id: 2, amount: 2, keyword: .burn),
                feedbackEvent(id: 3, amount: 3, keyword: .poison),
                feedbackEvent(id: 4, amount: 4, keyword: .holy),
                feedbackEvent(id: 5, amount: 5, keyword: .burn, targetID: "hero"),
            ],
            at: now
        )

        let enemyItems = session.feedback.activeItems
            .filter { $0.targetID == "enemy" }
            .sorted { $0.id < $1.id }
        let stagger = TrinketMotion.Battle.feedbackStreamStagger
        for (index, item) in enemyItems.enumerated() {
            let expected = stagger * Double(index)
            #expect(abs(item.availableAt.timeIntervalSince(now) - expected) < 0.001)
        }

        // Each target owns its own stream clock.
        let heroItem = session.feedback.activeItems.first { $0.targetID == "hero" }
        #expect(heroItem?.availableAt == now)
        #expect(session.feedback.activeItems.allSatisfy {
            abs(
                $0.expiresAt.timeIntervalSince($0.availableAt)
                    - TrinketMotion.Battle.chipDisplayDuration
            ) < 0.001
        })
    }

    @Test func feedbackVisualsQueueEveryDistinctChipInRapidSequence() {
        let session = BattleSession(openingHandDrawStagger: 0)
        let now = Date(timeIntervalSince1970: 200)
        let keywords: [Keyword] = [
            .bleed, .burn, .poison, .holy, .physical, .freeze, .stun, .leech,
        ]
        session.feedback.record(
            keywords.enumerated().map { index, keyword in
                feedbackEvent(id: index + 1, amount: index + 1, keyword: keyword)
            },
            at: now
        )

        let items = session.feedback.activeItems.sorted { $0.id < $1.id }
        #expect(items.count == 8)
        let stagger = TrinketMotion.Battle.feedbackStreamStagger
        for (index, item) in items.enumerated() {
            let expected = stagger * Double(index)
            #expect(abs(item.availableAt.timeIntervalSince(now) - expected) < 0.001)
        }
    }

    @Test func resetPreservesEnemyModifiersWhenBattleReset() throws {
        let enemy = try #require(GameContent.enemy(matching: "skeleton"))
        let configuration = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: enemy.combatant
        )
        let session = BattleSession(openingHandDrawStagger: 0)
        session.activeBattle = configuration

        session.activeBattle = try ActiveBattleConfigurationTestSupport.make(
            rngSeed: 1,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: enemy.combatant
        )

        #expect(
            session.state?.modifiers(for: enemy.combatant.id).damageTakenVulnerability(for: .holy) ?? 0 > 0
        )
    }

    @Test func autoEndTurnFiresOnlyWhenHandIsExhausted() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        #expect(session.hasPlayableCard)
        let tickWhilePlayable = try #require(session.state?.turnCount)

        session.considerAutoEndTurn()
        try await Task.sleep(for: .milliseconds(30))
        #expect(session.state?.turnCount == tickWhilePlayable)
        #expect(session.canEndTurn)

        while let card = session.hand.first(where: { session.isCardPlayable($0) }) {
            let resolution = session.playCard(
                cardID: card.id
            )
            if resolution.earnedGold != nil || session.outcome != nil {
                return
            }
        }

        #expect(session.canEndTurn)
        #expect(!session.hasPlayableCard)
        let tickBefore = try #require(session.state?.turnCount)

        try await waitForAutoEndTurn(session, after: tickBefore)

        #expect(session.state?.turnCount == tickBefore + 1)
    }

    @Test func trimMemoryFootprintReleasesBattleLogProjection() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))
        _ = session.playCard(cardID: card.id)
        session.syncLogForDisplay()
        #expect(!(session.state?.log.isEmpty ?? true))

        session.trimMemoryFootprint(releaseBattleLog: true)

        #expect(session.state?.log.isEmpty ?? false)
        #expect(!(session.state?.events.isEmpty ?? true))
    }

    private func waitForAutoEndTurn(_ session: BattleSession, after tickBefore: Int) async throws {
        for _ in 0 ..< 40 {
            if session.state?.turnCount == tickBefore + 1 {
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Auto-end turn did not resolve within the test timeout")
    }

    private func feedbackEvent(
        id: Int,
        amount: Int,
        keyword: Keyword = .bleed,
        targetID: String = "enemy"
    ) -> ActionEvent {
        ActionEvent(
            id: id,
            kind: .status,
            actorID: "hero",
            actorName: "Hero",
            abilityID: "bleed",
            abilityName: "Bleed",
            targetID: targetID,
            targetName: targetID.capitalized,
            amount: amount,
            keyword: keyword
        )
    }
}

@MainActor
struct BattleSessionPartyFeedbackStreamTests {
    @Test func partyFeedbackUsesOneIndependentStreamPerCombatant() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let now = Date(timeIntervalSince1970: 150)
        let stagger = TrinketMotion.Battle.feedbackStreamStagger
        session.feedback.record(
            [
                partyFeedbackEvent(id: 1, amount: 1, keyword: .bleed, targetID: "hero"),
                partyFeedbackEvent(id: 2, amount: 2, keyword: .burn, targetID: "hero"),
                partyFeedbackEvent(id: 3, amount: 3, keyword: .poison, targetID: "hero"),
                partyFeedbackEvent(id: 4, amount: 4, keyword: .holy, targetID: "companion"),
                partyFeedbackEvent(id: 5, amount: 5, keyword: .physical, targetID: "companion"),
            ],
            at: now
        )

        let heroItems = session.feedback.activeItems
            .filter { $0.targetID == "hero" }
            .sorted { $0.id < $1.id }
        for (index, item) in heroItems.enumerated() {
            let expected = stagger * Double(index)
            #expect(abs(item.availableAt.timeIntervalSince(now) - expected) < 0.001)
        }

        let companionItems = session.feedback.activeItems
            .filter { $0.targetID == "companion" }
            .sorted { $0.id < $1.id }
        for (index, item) in companionItems.enumerated() {
            let expected = stagger * Double(index)
            #expect(abs(item.availableAt.timeIntervalSince(now) - expected) < 0.001)
        }
    }

    private func partyFeedbackEvent(
        id: Int,
        amount: Int,
        keyword: Keyword,
        targetID: String
    ) -> ActionEvent {
        ActionEvent(
            id: id,
            kind: .status,
            actorID: "hero",
            actorName: "Hero",
            abilityID: "bleed",
            abilityName: "Bleed",
            targetID: targetID,
            targetName: targetID.capitalized,
            amount: amount,
            keyword: keyword
        )
    }
}
