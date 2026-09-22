import SwiftUI
import Testing
import TrinketContent
import TrinketContentTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionCardCueTests {
    @Test func `moving the hand moves new cast origins without changing a committed cast`() throws {
        let session = makeSession()
        defer { session.endBattle() }
        let card = try install(.slash, in: session)
        let frame = BattleHandLayout.frame(in: CGSize(width: 375, height: 667))
        let before = CardActivationRequest.restingRequest(for: card, index: 0, cardCount: 3, handFrame: frame)
        let casts = BattleCastPresentationState()
        defer { casts.reset() }
        casts.append(before)

        let moved = CardActivationRequest.restingRequest(
            for: card,
            index: 0,
            cardCount: 3,
            handFrame: frame.offsetBy(dx: 240, dy: -150),
        )
        #expect(moved.center.x == before.center.x + 240)
        #expect(moved.center.y == before.center.y - 150)
        #expect(moved.size == before.size)
        #expect(moved.rotation == before.rotation)
        #expect(casts.requests == [before])
        #expect(session.hand.contains(card))
    }

    @Test func `auto battle departs from rest and a manual play commits during its cast`() throws {
        let session = makeSession()
        defer { session.endBattle() }
        let card = try install(.slash, in: session)
        var state = try #require(session.engineState)
        let next = BattleCardCombatEngine.deal(.block, owner: .hero, context: &state)
        session.engineState = state
        session.installSimulationPresentation()
        session.isAutoBattleEnabled = true
        let configuration = try #require(session.activeBattle)
        let presentation = try #require(session.presentationContext)
        let casts = BattleCastPresentationState()
        defer { casts.reset() }
        let field = BattleFieldLane(
            configuration: configuration,
            presentationContext: presentation,
            battleSession: session,
            presentation: session.presentation,
            interactionState: BattleInteractionState(),
            castPresentation: casts,
        )
        let battleSize = CGSize(width: 375, height: 667)
        let handFrame = BattleHandLayout.frame(in: battleSize)
        let departure = CardActivationRequest.restingRequest(
            for: card, index: 0, cardCount: session.hand.count, handFrame: handFrame,
        )
        #expect(field.playAutoBattleCard(card, handFrame: handFrame))
        #expect(!session.hand.contains(card))
        #expect(session.cardCues.current?.mode == .tapCommit)
        let automaticCast = try #require(casts.request)
        #expect(automaticCast.center == departure.center)
        #expect(automaticCast.size == departure.size)
        #expect(automaticCast.rotation == departure.rotation)
        let automaticAction = try #require(session.feedback.scheduledActions.first)
        #expect(!automaticAction.deliversResultsImmediately)
        #expect(automaticAction.swingAt > automaticAction.startAt)

        #expect(session.canInteractWithHand)
        session.beginCardCue(next, mode: .tapCommit)
        let manualCast = CardActivationRequest.restingRequest(
            for: next, index: 0, cardCount: session.hand.count, handFrame: handFrame,
        )
        #expect(field.playCard(next, request: manualCast))
        #expect(session.hand.isEmpty)
        #expect(casts.requests.map(\.id) == [automaticCast.id, manualCast.id])
        _ = try state.playCard(cardID: card.id)
        _ = try state.playCard(cardID: next.id)
        #expect(session.engineState?.events == state.events)
        #expect(session.engineState?.rng == state.rng)

        session.isAutoBattleEnabled = false
        #expect(!field.playAutoBattleCard(card, handFrame: handFrame))
        #expect(casts.requests.map(\.id) == [automaticCast.id, manualCast.id])
        casts.remove(id: automaticCast.id)
        #expect(casts.requests.map(\.id) == [manualCast.id])
        #expect(session.hand.isEmpty)
    }

    @Test func `lifting a card cues without playing it`() throws {
        let session = makeSession()
        let card = try install(.spikedShield, in: session)
        let rng = session.engineState?.rng
        let health = session.engineState?.roster.enemy.currentHealth
        session.beginCardCue(card)
        let cue = try #require(session.cardCues.current)
        #expect(cue.mode == .preview)
        #expect(cue.cardID == card.id)
        #expect(cue.phase == .lifted)
        #expect(cue.denial == nil)
        #expect(session.engineState?.rng == rng)
        #expect(session.engineState?.roster.enemy.currentHealth == health)
        #expect(session.hand.contains(card))
        session.cancelCardCue(card)
        #expect(session.cardCues.current == nil)
    }

    @Test func `tap cue keeps tap mode through commitment`() throws {
        let session = makeSession()
        let card = try install(.heal, in: session)
        session.beginCardCue(card, mode: .tapCommit)
        #expect(session.cardCues.current?.mode == .tapCommit)
        #expect(session.playCard(cardID: card.id, requiresLift: true).didCommit)
        #expect(session.cardCues.current?.mode == .tapCommit)
        session.clearCardCues()
    }

    @Test func `tap commitment preserves the resource quote until feedback completes`() throws {
        let session = makeSession()
        let card = try install(.darkPact, in: session)
        session.beginCardCue(card)
        let before = try #require(session.cardCues.current)
        #expect(before.resources.first?.amount == 1)
        #expect(before.actorID == session.heroID)
        #expect(session.playCard(cardID: card.id, requiresLift: true).didCommit)
        #expect(session.cardCues.current?.phase == .committed)
        #expect(session.cardCues.current?.resources == before.resources)
        session.cancelCardCue(card)
        #expect(session.cardCues.current?.phase == .committed)
        session.clearCardCues()
    }

    @Test func `a late cancellation cannot clear a newer card cue`() throws {
        let session = makeSession()
        let first = try install(.heal, in: session)
        session.beginCardCue(first)
        let second = try install(.briarShield, in: session)
        session.beginCardCue(second)
        session.cancelCardCue(first)
        #expect(session.cardCues.current?.cardID == second.id)
        #expect(session.cardCues.current?.phase == .lifted)
        session.clearCardCues()
    }

    @Test func `inspection suspension and reset clear lifted cues`() throws {
        let session = makeSession()
        let card = try install(.heal, in: session)
        session.beginCardCue(card)
        session.presentAbilityDetail(card.ability)
        #expect(session.cardCues.current == nil)
        session.overlayAbilityDetail = nil
        session.beginCardCue(card)
        session.setSuspendedForScenePhase(true)
        #expect(session.cardCues.current == nil)
        session.setSuspendedForScenePhase(false)
        #expect(!session.playCard(cardID: card.id, requiresLift: true).didCommit)
        #expect(session.hand.contains(card))
        session.beginCardCue(card)
        session.clearRunState()
        #expect(session.cardCues.current == nil)
    }

    @Test func `two quick taps may both commit while only the latest preview remains visible`() throws {
        let session = makeSession()
        let first = try install(.briarShield, in: session)
        var state = try #require(session.engineState)
        let second = BattleCardCombatEngine.deal(.manaBerries, owner: .hero, context: &state)
        session.engineState = state
        session.installSimulationPresentation()
        session.beginCardCue(first)
        session.beginCardCue(second)
        session.cancelCardCue(second)
        #expect(session.cardCues.hasLift(for: first.id))
        session.beginCardCue(second)
        #expect(session.playCard(cardID: first.id, requiresLift: true).didCommit)
        #expect(session.cardCues.current?.cardID == second.id)
        #expect(session.playCard(cardID: second.id, requiresLift: true).didCommit)
        #expect(session.cardCues.current?.phase == .committed)
        session.clearCardCues()
    }

    @Test func `denied health costs highlight the owner while stale cards do not claim a resource problem`() throws {
        let session = makeSession()
        let card = try install(.darkPact, in: session)
        var state = try #require(session.engineState)
        state.roster.mutateRuntime(for: state.hero) { $0.currentHealth = 1 }
        session.engineState = state
        session.installSimulationPresentation()
        session.denyCardCue(card)
        let cue = try #require(session.cardCues.current)
        #expect(cue.phase == .denied)
        #expect(cue.denial == .insufficientHealth)
        #expect(cue.actorID == state.hero.id)
        #expect(session.engineState?.roster.hero.currentHealth == 1)
        session.clearCardCues()
        _ = state.hand.remove(id: card.id)
        session.engineState = state
        session.denyCardCue(card)
        #expect(session.cardCues.current == nil)
    }

    private func makeSession() -> BattleSession {
        BattleSessionTestSupport.makePassiveSession()
    }

    private func install(_ ability: Ability, in session: BattleSession) throws -> BattleCard {
        var state = try #require(session.engineState)
        state.hand = BattleHand()
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &state)
        session.engineState = state
        session.installSimulationPresentation()
        return card
    }
}
