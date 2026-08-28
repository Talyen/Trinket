import BattleEngine
import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketTestSupport
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionSimulationTests {
    @Test func victoryPresentationHoldsChromeAndLocksRetreatUntilConfiguredDelay() async throws {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(openingHandDrawStagger: 0, outcomePresentationDelayOverride: 0.05)
        session.partyCelebrateDelayOverride = .zero
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            rngSeed: 0,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )
        _ = session.activate(configuration, presentation: presentation)

        #expect(session.canRetreat)
        BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(session.outcome == .victory)
        #expect(session.spectacle.victorySummary != nil)
        #expect(!session.spectacle.isShowingVictory)
        #expect(!session.canRetreat)
        let heroID = try #require(session.heroID)
        let companionID = try #require(session.companionID)
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
        session.partyCelebrateDelayOverride = .zero
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            runKey: BattleRunKey("journey|\(stage.id)"),
            rngSeed: 0,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageRewardsAlreadyClaimed: true,
            hasProgressionRewards: true,
            musicStageID: stage.id
        )
        _ = session.activate(configuration)
        session.installPresentationContext(presentation)

        let earnedGold = BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(earnedGold == session.earnedGold ?? 0)
        #expect(!(session.spectacle.isShowingVictory))
        #expect(session.spectacle.victorySummary == nil)
        let heroID = try #require(session.heroID)
        let companionID = try #require(session.companionID)
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
        let milestoneIDs = Set((session.engineState?.events ?? []).filter { $0.kind == .milestone }.map(\.id))
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

        #expect(committed == .committed)
        #expect(rejected == .rejected)
    }

    @Test func presentationProjectionTracksSimulationWithoutExposingLogStorage() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let configurationID = try #require(session.activeBattle?.id)
        let initialEnemyHealth = try #require(session.presentation.enemy?.health)
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        _ = session.playCard(cardID: card.id)

        let engineState = try #require(session.engineState)
        #expect(session.presentation.configurationID == configurationID)
        #expect(session.presentation.hand == engineState.hand.cards)
        #expect(session.presentation.enemy?.health == engineState.health(of: engineState.enemy))
        #expect((session.presentation.enemy?.health ?? initialEnemyHealth) <= initialEnemyHealth)

        session.endBattle()

        #expect(session.activeBattle == nil)
        #expect(session.presentation.configurationID == nil)
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

        while !session.isBattleOver {
            session.endTurn()
        }

        #expect(session.engineState?.isPartyDefeated == true)
        let recordedIDs = Set(session.feedback.eventRecordedAt.keys)
        let milestoneIDs = Set((session.engineState?.events ?? []).filter { $0.kind == .milestone }.map(\.id))
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
        let engineState = try #require(session.engineState)
        #expect(engineState.health(of: engineState.enemy) < 100)

        _ = session.restart(BattleRunConfigurationTestSupport.make(
            rngSeed: BattleSessionTestSupport.deterministicBattleSeed,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        ).configuration)

        #expect(session.feedback.activeItems.isEmpty)
        let resetState = try #require(session.engineState)
        #expect(resetState.health(of: resetState.enemy) == 100)
        #expect(resetState.health(of: resetState.hero) == party.hero.maxHealth)
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

    @Test func feedbackBridgeUninstallIsOwnerScoped() {
        let session = BattleSession(openingHandDrawStagger: 0)
        let survivingOwnerID = UUID()
        let departingOwnerID = UUID()
        let staleOwnerID = UUID()
        var receivedUpdates: [CombatFeedbackUpdate] = []

        session.feedback.installBridge(ownerID: survivingOwnerID) { update in
            receivedUpdates.append(update)
        }
        session.feedback.installBridge(ownerID: departingOwnerID) { _ in }
        session.feedback.uninstallBridge(ownerID: staleOwnerID)
        session.feedback.record([feedbackEvent(id: 1, amount: 2)])
        #expect(receivedUpdates.count == 1)

        session.feedback.uninstallBridge(ownerID: departingOwnerID)
        session.feedback.record([feedbackEvent(id: 2, amount: 3)])
        #expect(receivedUpdates.count == 2)

        session.feedback.uninstallBridge(ownerID: survivingOwnerID)
        session.feedback.record([feedbackEvent(id: 3, amount: 4)])
        #expect(receivedUpdates.count == 2)
    }

    @Test func resetPreservesEnemyModifiersWhenBattleReset() throws {
        let enemy = try #require(GameContent.enemy(matching: "skeleton"))
        let enemyModifiers = CombatModifierProfile(modifiers: [
            .damageTakenVulnerability(.holy, 0.30),
            .damageTakenPercent(.bleed, 0.30),
        ])
        let (configuration, _) = BattleRunConfigurationTestSupport.make(
            rngSeed: 0,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: enemy.combatant,
            enemyModifiers: enemyModifiers
        )
        let session = BattleSession(openingHandDrawStagger: 0)
        _ = session.activate(configuration)

        _ = session.restart(BattleRunConfigurationTestSupport.make(
            rngSeed: 1,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: enemy.combatant,
            enemyModifiers: enemyModifiers
        ).configuration)

        #expect(
            (session.engineState?.modifiers(for: enemy.combatant.id)
                .damageTakenVulnerability(for: .holy) ?? 0) > 0
        )
    }

    @Test func autoEndTurnFiresOnlyWhenHandIsExhausted() async throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        #expect(session.hasPlayableCard)

        while let card = session.hand.first(where: { session.isCardPlayable($0) }) {
            let resolution = session.playCard(
                cardID: card.id
            )
            if resolution == .rejected || session.outcome != nil {
                return
            }
        }

        #expect(session.canEndTurn)
        #expect(!session.hasPlayableCard)
        let tickBefore = try #require(session.engineState?.turnCount)

        try await waitForAutoEndTurn(session, after: tickBefore)

        #expect(session.engineState?.turnCount == tickBefore + 1)
    }

    @Test func trimMemoryFootprintReleasesBattleLogProjection() throws {
        let session = try BattleSessionTestSupport.makeConfiguredSession()
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))
        _ = session.playCard(cardID: card.id)
        session.syncLogForDisplay()
        #expect(!(session.logEntries.isEmpty))

        session.trimMemoryFootprint(releaseBattleLog: true)

        #expect(session.logEntries.isEmpty)
        #expect(!(session.engineState?.events.isEmpty ?? true))
    }

    @Test func trimMemoryFootprintKeepsPreparedArtworkPinNamesWhilePrepared() {
        let session = BattleSession(openingHandDrawStagger: 0)
        session.lifecyclePhase = .prepared
        session.preparedArtworkNames = ["opening-hand-art"]

        session.trimMemoryFootprint(releaseBattleLog: true)

        #expect(session.preparedArtworkNames == ["opening-hand-art"])
    }

    @Test func trimMemoryFootprintReleasesPreparedArtworkPinNamesWhenIdle() {
        let session = BattleSession(openingHandDrawStagger: 0)
        session.lifecyclePhase = .idle
        session.preparedArtworkNames = ["opening-hand-art"]

        session.trimMemoryFootprint(releaseBattleLog: true)

        #expect(session.preparedArtworkNames.isEmpty)
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
private func waitForAutoEndTurn(_ session: BattleSession, after tickBefore: Int) async throws {
    guard try await BattleSessionTestSupport.waitUntil(condition: {
        session.engineState?.turnCount == tickBefore + 1
    }) else {
        Issue.record("Auto-end turn did not resolve within the test timeout")
        return
    }
}

extension BattleSessionSimulationTests {
    @Test func hitAndAttackReactionBridgesNotifyOnlyTheMatchingCombatant() {
        let session = BattleSession(openingHandDrawStagger: 0)
        let heroOwner = UUID()
        let enemyOwner = UUID()
        var heroHits: [CombatantHitReaction?] = []
        var enemyHits: [CombatantHitReaction?] = []
        var heroAttacks: [CombatantAttackReaction?] = []
        var enemyAttacks: [CombatantAttackReaction?] = []

        session.feedback.installHitReactionBridge(ownerID: heroOwner, combatantID: "hero") {
            heroHits.append($0)
        }
        session.feedback.installHitReactionBridge(ownerID: enemyOwner, combatantID: "enemy") {
            enemyHits.append($0)
        }
        session.feedback.installAttackReactionBridge(ownerID: heroOwner, combatantID: "hero") {
            heroAttacks.append($0)
        }
        session.feedback.installAttackReactionBridge(ownerID: enemyOwner, combatantID: "enemy") {
            enemyAttacks.append($0)
        }

        #expect(heroHits == [nil])
        #expect(enemyHits == [nil])
        #expect(heroAttacks == [nil])
        #expect(enemyAttacks == [nil])

        let enemyHit = CombatantHitReaction(id: 42, kind: .damage)
        session.feedback.hitReactionsByTargetID["enemy"] = enemyHit
        session.feedback.noteHitReactionsChanged(for: ["enemy"])

        let heroAttack = CombatantAttackReaction(id: 42, kind: .attack, phase: .swing)
        session.publishAttackReaction(heroAttack, for: "hero")

        #expect(heroHits == [nil])
        #expect(enemyHits == [nil, enemyHit])
        #expect(heroAttacks == [nil, heroAttack])
        #expect(enemyAttacks == [nil])

        session.feedback.clear()

        #expect(heroHits == [nil, nil])
        #expect(enemyHits == [nil, enemyHit, nil])
        #expect(heroAttacks == [nil, heroAttack, nil])
        #expect(enemyAttacks == [nil, nil])

        session.feedback.hitReactionsByTargetID["enemy"] = enemyHit
        session.feedback.noteHitReactionsChanged(for: ["enemy"])
        session.publishAttackReaction(heroAttack, for: "hero")

        #expect(heroHits == [nil, nil])
        #expect(enemyHits == [nil, enemyHit, nil, enemyHit])
        #expect(heroAttacks == [nil, heroAttack, nil, heroAttack])
        #expect(enemyAttacks == [nil, nil])

        session.feedback.uninstallHitReactionBridge(ownerID: heroOwner)
        session.feedback.uninstallHitReactionBridge(ownerID: enemyOwner)
        session.feedback.uninstallAttackReactionBridge(ownerID: heroOwner)
        session.feedback.uninstallAttackReactionBridge(ownerID: enemyOwner)
    }
}
