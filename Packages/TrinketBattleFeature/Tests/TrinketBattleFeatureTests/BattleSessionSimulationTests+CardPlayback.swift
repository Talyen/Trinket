import Foundation
import SwiftUI
import Testing
import TrinketContent
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

extension BattleSessionSimulationTests {
    @Test(arguments: [false, true])
    func `automatic plays never block the next hand command`(nested: Bool) throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        let card = try installPackTactics(in: session, nested: nested)
        var immediate = try #require(session.engineState)
        _ = try immediate.playCard(cardID: card.id)
        #expect(session.playCard(cardID: card.id) == .committed)
        #expect(session.hand == immediate.hand.cards)
        #expect(session.canEndTurn)
        #expect(session.cardPlayback.casts.map(\.card.ability.id) == (nested
                ? [Ability.packTactics.id, Ability.slash.id] : [Ability.bash.id]))
        let next = try #require(session.hand.first)
        _ = try immediate.playCard(cardID: next.id)
        #expect(session.playCard(cardID: next.id) == .committed)
        #expect(session.hand == immediate.hand.cards)
        #expect(session.engineState?.events == immediate.events)
        #expect(session.engineState?.rng == immediate.rng)
        #expect(session.engineState?.heroDeck == immediate.heroDeck)
        #expect(session.engineState?.companionDeck == immediate.companionDeck)
        for owner in BattleParticipant.allCases {
            #expect(session.engineState?.roster[owner] == immediate.roster[owner])
        }
    }

    @Test(arguments: [false, true])
    func `finishing taps intentionally animate without changing settled combat`(victory: Bool) throws {
        let session = BattleSessionTestSupport.makePassiveSession(heroHealth: 1)
        defer { session.endBattle() }
        session.outcomePresentationDelayOverride = .seconds(60)
        var state = try #require(session.engineState)
        state.hand = BattleHand()
        let card = BattleCardCombatEngine.deal(.darkPact, owner: .hero, context: &state)
        if victory {
            state.roster.enemy.currentHealth = 0
        } else {
            state.roster.hero.currentHealth = 0
            state.roster.companion.currentHealth = 0
        }
        session.engineState = state
        session.installSimulationPresentation()
        session.handleOutcomeIfNeeded(at: .now)
        let generation = session.spectacle.outcomeTask.generation
        let summary = session.spectacle.outcomePresentation
        #expect(!session.canAcceptBattleCommands)
        #expect(session.canInteractWithHand)
        #expect(session.playCard(cardID: card.id) == .committed)
        #expect(session.playCard(cardID: card.id) == .rejected)
        #expect(session.hand.isEmpty)
        #expect(session.engineState?.hand == state.hand)
        #expect(session.engineState?.events == state.events)
        #expect(session.engineState?.rng == state.rng)
        #expect(session.engineState?.goldFlow == state.goldFlow)
        #expect(session.engineState?.heroDeck == state.heroDeck)
        #expect(session.engineState?.companionDeck == state.companionDeck)
        for owner in BattleParticipant.allCases {
            #expect(session.engineState?.roster[owner] == state.roster[owner])
        }
        #expect(session.spectacle.outcomeTask.generation == generation)
        #expect(session.spectacle.outcomePresentation == summary)
        #expect(session.cardPlayback.casts.isEmpty)
    }

    @Test func `lethal retaliation preserves remaining visual cards after engine cleanup`() throws {
        let session = BattleSessionTestSupport.makePassiveSession(heroHealth: 1)
        defer { session.endBattle() }
        session.outcomePresentationDelayOverride = .seconds(60)
        var state = try #require(session.engineState)
        state.hand = BattleHand()
        state.roster.companion.currentHealth = 0
        state.roster.hero.hasConsumedDeathsDoor = true
        state.appendEffect(.thorns(100), to: state.enemy, sourceID: state.enemy.id, remainingTurns: 0)
        let attack = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &state)
        let remaining = BattleCardCombatEngine.deal(.block, owner: .hero, context: &state)
        session.engineState = state
        session.installSimulationPresentation()
        #expect(session.playCard(cardID: attack.id) == .committed)
        #expect(session.outcome == .defeat)
        #expect(session.engineState?.hand.isEmpty == true)
        #expect(session.hand.map(\.id) == [remaining.id])
        #expect(session.playCard(cardID: remaining.id) == .committed)
        #expect(session.hand.isEmpty)
    }

    @Test func `automatic visual completion cannot restore a stale hand`() throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        let card = try installPackTactics(in: session)
        #expect(session.playCard(cardID: card.id) == .committed)
        let cast = try #require(session.cardPlayback.casts.first)
        session.setSuspendedForScenePhase(true)
        #expect(session.cardPlayback.casts.first?.pausedAt != nil)
        #expect(!session.canInteractWithHand)
        session.setSuspendedForScenePhase(false)
        let next = try #require(session.hand.first)
        #expect(session.playCard(cardID: next.id) == .committed)
        let hand = session.hand
        session.cardPlayback.remove(id: cast.id)
        #expect(session.hand == hand)
        let outgoing = session.presentation
        session.endBattle()
        #expect(outgoing.hand == hand)
        #expect(outgoing.cardPlayback.casts.isEmpty)
        #expect(session.cardPlayback !== outgoing.cardPlayback)
    }

    @Test func `consecutive manual casts coexist and stale completion removes only its own cast`() {
        let casts = BattleCastPresentationState()
        defer { casts.reset() }
        let first = CardActivationRequest(
            artworkName: nil,
            center: .zero,
            size: .zero,
            rotation: 0,
            verticalTilt: 0,
            scale: 1,
            keywords: [.physical],
        )
        casts.append(first)
        let second = CardActivationRequest(
            artworkName: nil,
            center: .zero,
            size: .zero,
            rotation: 0,
            verticalTilt: 0,
            scale: 1,
            keywords: [.physical],
        )
        casts.append(second)
        #expect(casts.requests.map(\.id) == [first.id, second.id])
        casts.remove(id: first.id)
        #expect(casts.requests.map(\.id) == [second.id])
        for _ in 0 ..< 8 {
            casts.append(CardActivationRequest(
                artworkName: nil,
                center: .zero,
                size: .zero,
                rotation: 0,
                verticalTilt: 0,
                scale: 1,
                keywords: [.physical],
            ))
        }
        #expect(casts.requests.count == 6)
        casts.remove(id: second.id)
        #expect(casts.requests.count == 6)
    }

    private func installPackTactics(in session: BattleSession, nested: Bool = false) throws -> BattleCard {
        var state = try #require(session.engineState)
        state.hand = BattleHand()
        let card = BattleCardCombatEngine.deal(.packTactics, owner: .hero, context: &state)
        _ = BattleCardCombatEngine.deal(.block, owner: .hero, context: &state)
        _ = BattleCardCombatEngine.deal(.block, owner: .companion, context: &state)
        if nested {
            _ = BattleCardCombatEngine.deal(.block, owner: .hero, context: &state)
        }
        state.heroDeck = CombatDeck(abilities: [.slash, .block])
        state.companionDeck = CombatDeck(abilities: [nested ? .packTactics : .bash, .block])
        session.engineState = state
        session.installSimulationPresentation()
        session.feedback.clear()
        return card
    }
}
