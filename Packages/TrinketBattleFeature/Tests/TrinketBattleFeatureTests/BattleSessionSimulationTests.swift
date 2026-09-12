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
    @Test func `turn hand is ready immediately and suspension only pauses interaction`() throws {
        let session = BattleSessionTestSupport.makeConfiguredSession(autoEndTurnDelay: 60)
        defer { session.endBattle() }
        let card = try #require(session.hand.first)
        #expect(session.playCard(cardID: card.id) == .committed)
        session.endTurn()
        #expect(session.canEndTurn)
        #expect(session.hand == session.engineState?.hand.cards)
        let next = try #require(session.hand.first)
        session.setSuspendedForScenePhase(true)
        #expect(session.playCard(cardID: next.id) == .rejected)
        session.setSuspendedForScenePhase(false)
        #expect(session.playCard(cardID: next.id) == .committed)
    }

    @Test func `defeat presentation locks retreat without victory chrome`() {
        let session = BattleSessionTestSupport.makeConfiguredSession(
            hero: CombatantFixtures.passiveHero(maxHealth: 1),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 1),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 500,
                actionIntervalTurns: CombatantFixtures.quickWinTurnInterval,
                abilities: [.slash],
            ),
        )
        BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(session.outcome == .defeat)
        #expect(session.spectacle.outcomePresentation == .defeat)
        #expect(!session.canRetreat)
    }

    @Test func `victory presentation holds chrome and locks retreat until configured delay`() async throws {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(outcomePresentationDelayOverride: 0.05)
        session.partyCelebrateDelayOverride = .zero
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            rngSeed: 0,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
        )
        _ = session.activate(configuration, presentation: presentation)

        #expect(session.canRetreat)
        BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(session.outcome == .victory)
        #expect(session.spectacle.outcomePresentation.victorySummaryIfAvailable != nil)
        #expect(!session.spectacle.outcomePresentation.isOutcomePresented)
        #expect(!session.spectacle.outcomePresentation.isVictoryPresented)
        #expect(!session.canRetreat)
        let heroID = try #require(session.heroID)
        let companionID = try #require(session.companionID)
        #expect(session.feedback.hitReactionsByTargetID[heroID]?.kind == .celebrate)
        #expect(session.feedback.hitReactionsByTargetID[companionID]?.kind == .celebrate)
        let presentationTask = try #require(session.spectacle.outcomeTask.task)
        await presentationTask.value
        #expect(session.spectacle.outcomePresentation.isOutcomePresented)
        #expect(session.spectacle.outcomePresentation.isVictoryPresented)
        #expect(!session.canRetreat)
    }

    @Test func `claimed stage rewards auto complete then persist retry restores loot chrome`() throws {
        let party = BattlePartyFixtures.quickWinParty()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let session = BattleSession(outcomePresentationDelayOverride: 0)
        session.partyCelebrateDelayOverride = .zero
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            runKey: BattleRunKey("journey|\(stage.id)"),
            rngSeed: 0,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageRewardsAlreadyClaimed: true,
            hasProgressionRewards: true,
            musicStageID: stage.id,
        )
        _ = session.activate(configuration, presentation: presentation)

        let earnedGold = BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(earnedGold == session.goldFlow?.net ?? 0)
        #expect(!session.spectacle.outcomePresentation.isVictoryPresented)
        #expect(session.spectacle.outcomePresentation.victorySummaryIfAvailable == nil)
        let heroID = try #require(session.heroID)
        let companionID = try #require(session.companionID)
        #expect(session.feedback.hitReactionsByTargetID[heroID]?.kind == .celebrate)
        #expect(session.feedback.hitReactionsByTargetID[companionID]?.kind == .celebrate)

        session.presentVictoryChromeForPersistRetry()

        #expect(session.spectacle.outcomePresentation.isVictoryPresented)
        #expect(session.spectacle.outcomePresentation.victorySummaryIfAvailable != nil)
        #expect(!session.canRetreat)
    }

    @Test func `play card retires expired feedback and excludes milestones`() throws {
        let session = BattleSessionTestSupport.makeConfiguredSession()
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        session.feedback.clear()
        session.feedback.record([feedbackEvent(id: 9000, amount: 2)])
        let expired = try #require(session.feedback.activeItems.first)
        var removedIDs: Set<Int> = []
        session.feedback.installBridge(ownerID: UUID()) { update in
            if case let .remove(ids) = update {
                removedIDs.formUnion(ids)
            }
        }
        _ = session.playCard(cardID: card.id, at: expired.expiresAt.addingTimeInterval(0.01))

        #expect(removedIDs == [expired.id])
        #expect(!(session.feedback.activeItems.isEmpty))
        let recordedIDs = Set(session.feedback.activeItems.flatMap(\.sourceEventIDs))
        let milestoneIDs = Set((session.engineState?.events ?? []).filter { $0.kind == .milestone }.map(\.id))
        #expect(recordedIDs.isDisjoint(with: milestoneIDs))
    }

    @Test func `play card distinguishes successful non victory from rejection`() throws {
        let session = BattleSessionTestSupport.makeConfiguredSession()
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        let committed = session.playCard(
            cardID: card.id,
        )
        let rejected = session.playCard(
            cardID: Int.max,
        )

        #expect(committed == .committed)
        #expect(rejected == .rejected)
    }

    @Test func `presentation projection tracks simulation without exposing log storage`() throws {
        let session = BattleSessionTestSupport.makeConfiguredSession(
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: [.slash]),
        )
        let configurationID = try #require(session.activeBattle?.id)
        let initialEnemyHealth = try #require(session.presentation.enemy?.health)
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        _ = session.playCard(cardID: card.id)

        let engineState = try #require(session.engineState)
        #expect(session.presentation.configurationID == configurationID)
        #expect(session.presentation.hand == engineState.hand.cards)
        #expect(session.presentation.enemy?.health == engineState.health(of: engineState.enemy))
        #expect((session.presentation.enemy?.health ?? initialEnemyHealth) <= initialEnemyHealth)

        let outgoingSpectacle = session.spectacle
        outgoingSpectacle.outcomePresentation = .defeat
        let outgoingPresentation = session.presentation
        let outgoingHero = outgoingPresentation.hero
        let outgoingCompanion = outgoingPresentation.companion
        let outgoingEnemy = outgoingPresentation.enemy
        let outgoingHand = outgoingPresentation.hand
        #expect(!outgoingHand.isEmpty)

        session.endBattle()

        #expect(session.activeBattle == nil)
        #expect(session.presentation !== outgoingPresentation)
        #expect(session.spectacle !== outgoingSpectacle)
        #expect(session.spectacle.outcomePresentation == .battle)
        #expect(outgoingSpectacle.outcomePresentation == .defeat)
        #expect(session.presentation.configurationID == nil)
        #expect(session.presentation.hand.isEmpty)
        #expect(session.presentation.hero == nil)
        #expect(session.presentation.companion == nil)
        #expect(session.presentation.enemy == nil)
        #expect(outgoingPresentation.configurationID == configurationID)
        #expect(outgoingPresentation.hand == outgoingHand)
        #expect(outgoingPresentation.hero == outgoingHero)
        #expect(outgoingPresentation.companion == outgoingCompanion)
        #expect(outgoingPresentation.enemy == outgoingEnemy)
    }

    @Test func `end turn excludes milestones from feedback when battle ends`() {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 1, abilities: [])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 1, abilities: [])
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: [.slash],
        )
        let session = BattleSessionTestSupport.makeConfiguredSession(hero: hero, companion: companion, enemy: enemy)

        while !session.isBattleOver {
            session.endTurn()
        }

        #expect(session.engineState?.isPartyDefeated == true)
        let recordedIDs = Set(session.feedback.activeItems.flatMap(\.sourceEventIDs))
        let milestoneIDs = Set((session.engineState?.events ?? []).filter { $0.kind == .milestone }.map(\.id))
        #expect(recordedIDs.isDisjoint(with: milestoneIDs))
    }

    @Test func `reset clears feedback and rebuilds state when reset called`() throws {
        let party = BattlePartyFixtures.quickWinParty(enemyMaxHealth: 100)
        let session = BattleSessionTestSupport.makeConfiguredSession(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
        )
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))

        _ = session.playCard(cardID: card.id)
        #expect(!(session.feedback.activeItems.isEmpty))
        let engineState = try #require(session.engineState)
        #expect(engineState.health(of: engineState.enemy) < 100)

        _ = session.restart(BattleRunConfigurationTestSupport.make(
            rngSeed: CombatantFixtures.deterministicBattleSeed,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
        ).configuration)

        #expect(session.feedback.activeItems.isEmpty)
        let resetState = try #require(session.engineState)
        #expect(resetState.health(of: resetState.enemy) == 100)
        #expect(resetState.health(of: resetState.hero) == party.hero.maxHealth)
    }

    @Test func `feedback bridge uninstall is owner scoped`() {
        let session = BattleSession()
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

    @Test func `reset preserves enemy modifiers when battle reset`() throws {
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
            enemyModifiers: enemyModifiers,
        )
        let session = BattleSession()
        _ = session.activate(configuration)

        _ = session.restart(BattleRunConfigurationTestSupport.make(
            rngSeed: 1,
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: enemy.combatant,
            enemyModifiers: enemyModifiers,
        ).configuration)

        #expect(
            (session.engineState?.modifiers(for: enemy.combatant.id)
                .damageTakenVulnerability(for: .holy) ?? 0) > 0,
        )
    }

    @Test func `auto end turn fires only when hand is exhausted`() async throws {
        let session = BattleSessionTestSupport.makeConfiguredSession()
        #expect(session.hasPlayableCard)

        while let card = session.hand.first(where: { session.isCardPlayable($0) }) {
            let resolution = session.playCard(
                cardID: card.id,
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

    @Test func `trim memory footprint releases battle log projection`() throws {
        let session = BattleSessionTestSupport.makeConfiguredSession()
        let card = try #require(session.hand.first(where: { session.isCardPlayable($0) }))
        _ = session.playCard(cardID: card.id)
        session.syncEngineLog()
        #expect(!(session.logEntries.isEmpty))

        session.trimMemoryFootprint(releaseBattleLog: true)

        #expect(session.logEntries.isEmpty)
        #expect(!(session.engineState?.events.isEmpty ?? true))
    }

    private func feedbackEvent(
        id: Int,
        amount: Int,
        keyword: Keyword = .bleed,
        targetID: String = "enemy",
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
            keyword: keyword,
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
    @Test func `hit and attack reaction bridges notify only the matching combatant`() {
        let session = BattleSession()
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

extension BattleSessionSimulationTests {
    @Test func `animated turn playback has the same completed engine state as immediate presentation`() async throws {
        let enemy = CombatantFixtures.passiveEnemy(maxHealth: 200)
        let immediate = BattleSessionTestSupport.makeConfiguredSession(enemy: enemy, autoEndTurnDelay: 60)
        let animated = BattleSessionTestSupport.makeConfiguredSession(enemy: enemy, autoEndTurnDelay: 60)
        defer {
            immediate.endBattle()
            animated.endBattle()
        }
        let card = try #require(immediate.hand.first)
        #expect(immediate.playCard(cardID: card.id) == .committed)
        #expect(animated.playCard(cardID: card.id) == .committed)
        immediate.endTurn()
        animated.endTurn()
        animated.setSuspendedForScenePhase(true)
        let directState = try #require(immediate.engineState)
        let animatedState = try #require(animated.engineState)
        #expect(animatedState.hand == directState.hand)
        for owner in [BattleParticipant.hero, .companion, .enemy] {
            #expect(animatedState.roster[owner] == directState.roster[owner])
        }
        #expect(animatedState.events == directState.events)
        var directRNG = directState.rng
        var animatedRNG = animatedState.rng
        #expect(animatedRNG.next() == directRNG.next())
        #expect(!animated.canEndTurn)
        animated.setSuspendedForScenePhase(false)
        #expect(try await BattleSessionTestSupport.waitUntil { !animated.transitionTask.hasPendingTask })
        #expect(animated.hand == immediate.hand)
        #expect(animated.canEndTurn)
    }
}
