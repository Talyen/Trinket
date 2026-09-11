import Foundation
import Testing
import TrinketContent
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

extension BattleSessionSimulationTests {
    @Test(arguments: [false, true])
    func `pack tactics reveals each automatic play before casting`(nested: Bool) async throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        defer { session.endBattle() }
        let card = try installPackTactics(in: session, nested: nested)
        var immediate = try #require(session.engineState)
        let events = try immediate.playCard(cardID: card.id)
        #expect(session.playCard(cardID: card.id) == .committed)
        #expect(session.engineState?.hand == immediate.hand)
        #expect(session.engineState?.events == immediate.events)
        #expect(session.hand.count == 2)
        #expect(session.spectacle.ultimateHighlightsByActorID[immediate.hero.id]?.abilityID == Ability.packTactics.id)
        #expect(!session.canEndTurn)
        let remainingCard = try #require(session.hand.first)
        #expect(session.playCard(cardID: remainingCard.id) == .rejected)
        session.endTurn()
        #expect(session.engineState?.turnCount == immediate.turnCount)

        session.setSuspendedForScenePhase(true)
        let pausedIndex = session.transitionPlayback?.nextIndex
        for _ in 0 ..< 10 {
            await Task.yield()
        }
        #expect(session.transitionPlayback?.nextIndex == pausedIndex)
        session.setSuspendedForScenePhase(false)

        var revealedIDs: Set<Int> = []
        var castIDs: [Int] = []
        var castAbilities: [String] = []
        var sawStagedCard = false
        let completed = try await BattleSessionTestSupport.waitUntil {
            revealedIDs.formUnion(session.hand.map(\.id))
            if let staged = session.presentation.stagedCard {
                revealedIDs.insert(staged.id)
                sawStagedCard = true
            }
            #expect(session.hand.count <= BattleHand.maxSize)
            if let cast = session.cardPlayback.cast, castIDs.last != cast.card.id {
                #expect(revealedIDs.contains(cast.card.id))
                #expect(!session.hand.contains { $0.id == cast.card.id })
                #expect(session.presentation.stagedCard == nil)
                #expect(!session.canEndTurn)
                castIDs.append(cast.card.id)
                castAbilities.append(cast.card.ability.id)
            }
            return !session.transitionTask.hasPendingTask
        }
        #expect(completed)
        let expected: [Ability] = nested ? [.packTactics, .block, .block, .bash] : [.slash, .bash]
        #expect(castAbilities == expected.map(\.id))
        #expect(Set(castIDs).count == castIDs.count)
        #expect(!castIDs.contains(card.id))
        #expect(sawStagedCard == nested)
        #expect(session.hand == immediate.hand.cards)
        #expect(session.canEndTurn)
        let expectedFeedback = CombatFeedbackPresenter.makeItems(from: events, at: .now).flatMap(\.sourceEventIDs).sorted()
        #expect(session.feedback.activeItems.flatMap(\.sourceEventIDs).sorted() == expectedFeedback)
    }

    @Test func `lethal automatic play settles before victory and skips the next card`() async throws {
        let session = BattleSessionTestSupport.makePassiveSession(enemyHealth: 1)
        defer { session.endBattle() }
        let card = try installPackTactics(in: session)
        #expect(session.playCard(cardID: card.id) == .committed)
        #expect(session.engineState?.isBattleOver == true)
        #expect(session.spectacle.outcomePresentation == .battle)
        #expect(try await BattleSessionTestSupport.waitUntil { session.cardPlayback.cast != nil })
        #expect(session.cardPlayback.cast?.card.ability.id == Ability.slash.id)
        #expect(session.spectacle.outcomePresentation == .battle)
        #expect(!session.canEndTurn)
        #expect(try await BattleSessionTestSupport.waitUntil { !session.transitionTask.hasPendingTask })
        #expect(session.spectacle.outcomePresentation.isVictoryPresented)
        #expect(session.hand.contains { $0.ability.id == Ability.bash.id })
    }

    @Test func `ending battle invalidates suspended card playback`() async throws {
        let session = BattleSessionTestSupport.makePassiveSession()
        let card = try installPackTactics(in: session)
        #expect(session.playCard(cardID: card.id) == .committed)
        session.setSuspendedForScenePhase(true)
        let pending = try #require(session.transitionTask.task)
        let outgoing = session.presentation
        let hand = outgoing.hand
        session.endBattle()
        await pending.value
        #expect(outgoing.hand == hand)
        #expect(session.activeBattle == nil)
        #expect(session.transitionPlayback == nil)
        #expect(session.cardPlayback.cast == nil)
        #expect(session.cardPlayback.liftedCardID == nil)
        #expect(session.cardPlayback !== outgoing.cardPlayback)
        #expect(!session.canEndTurn)
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
        state.heroDeck = CombatDeck(abilities: [nested ? .packTactics : .slash, .block])
        state.companionDeck = CombatDeck(abilities: [.bash, .block])
        session.engineState = state
        session.installSimulationPresentation()
        session.feedback.clear()
        session.openingHandDrawStagger = .milliseconds(1)
        session.cardPlayback.delayOverride = .milliseconds(15)
        return card
    }
}
