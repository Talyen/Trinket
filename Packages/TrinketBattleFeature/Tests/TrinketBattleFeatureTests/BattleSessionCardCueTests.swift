import SwiftUI
import Testing
import TrinketContent
import TrinketContentTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionCardCueTests {
    @Test func `queued cards keep tap order skip invalid cards and clear on suspension`() {
        let casts = BattleCastPresentationState()
        defer { casts.reset() }
        let start = Date.now
        let request = CardActivationRequest(
            startedAt: start, artworkName: nil, center: .zero, size: .zero,
            rotation: 0, verticalTilt: 0, scale: 1, keywords: [],
        )
        casts.append(request)
        #expect(casts.shouldQueueManualInput(at: start))
        #expect(!casts.shouldQueueManualInput(at: start.addingTimeInterval(BattleMotion.manualCardInterval)))
        var played: [Int] = []
        casts.queueCard(id: 1) { _ in played.append(1); return true }
        casts.queueCard(id: 2) { _ in played.append(2); return false }
        casts.queueCard(id: 3) { _ in played.append(3); return true }
        casts.queueCard(id: 1) { _ in played.append(99); return true }
        #expect(casts.queuedCardIDs == [1, 2, 3])
        #expect(casts.blocksAutoBattle(at: start.addingTimeInterval(10)))
        casts.playNextQueuedCard()
        #expect(played == [1])
        #expect(casts.queuedCardIDs == [2, 3])
        casts.playNextQueuedCard()
        #expect(played == [1, 2, 3])
        #expect(casts.queuedCardIDs.isEmpty)
        casts.queueCard(id: 4) { _ in played.append(4); return true }
        casts.setSuspended(true, at: start)
        casts.playNextQueuedCard()
        #expect(played == [1, 2, 3])
        #expect(casts.queuedCardIDs.isEmpty)
    }

    @Test func `queued cards start on cadence while prior casts remain visible`() async throws {
        let casts = BattleCastPresentationState()
        defer { casts.reset() }
        let start = Date.now
        func request(at date: Date) -> CardActivationRequest {
            CardActivationRequest(
                startedAt: date, artworkName: nil, center: .zero, size: .zero,
                rotation: 0, verticalTilt: 0, scale: 1, keywords: [],
            )
        }
        casts.append(request(at: start))
        var starts: [Date] = []
        for id in 1 ... 2 {
            casts.queueCard(id: id) { _ in
                let date = Date.now
                starts.append(date)
                casts.append(request(at: date))
                return true
            }
        }
        let deadline = start.addingTimeInterval(3)
        while starts.count < 2, Date.now < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(starts.count == 2)
        if starts.count == 2 {
            #expect(starts[0].timeIntervalSince(start) >= BattleMotion.manualCardInterval - 0.02)
            #expect(starts[1].timeIntervalSince(starts[0]) >= BattleMotion.manualCardInterval - 0.02)
            #expect(BattleMotion.manualCardInterval < BattleMotion.cardActivationDuration)
        }
    }

    @Test func `retiring hand callbacks cannot play or cancel a replacement battle card`() throws {
        let session = makeSession()
        defer { session.endBattle() }
        let card = try install(.slash, in: session)
        let configuration = try #require(session.activeBattle)
        let context = try #require(session.presentationContext)
        let retiredPresentation = session.presentation
        let casts = BattleCastPresentationState()
        defer { casts.reset() }
        let field = BattleFieldLane(
            configuration: configuration, presentationContext: context,
            battleSession: session, presentation: retiredPresentation,
            interactionState: BattleInteractionState(), castPresentation: casts,
        )
        let frame = BattleHandLayout.frame(in: CGSize(width: 375, height: 667))
        let request = CardActivationRequest.restingRequest(
            for: card, index: 0, cardCount: session.hand.count, handFrame: frame,
        )

        session.endBattle()
        #expect(!field.playCard(card, request: request))
        // Reuse even the configuration ID: display lifetime, not a card or run
        // identifier, owns permission to issue commands.
        #expect(session.activate(configuration, presentation: context))
        let replacement = try install(.slash, in: session)
        #expect(replacement.id == card.id)
        #expect(session.isCardPlayable(replacement))
        session.beginCardCue(replacement)
        let events = session.engineState?.events
        let rng = session.engineState?.rng

        field.cancelCardLift(for: card)
        #expect(session.cardCues.current?.phase == .lifted)
        #expect(!field.playCard(card, request: request))
        session.isAutoBattleEnabled = true
        #expect(!field.playAutoBattleCard(card, handFrame: frame))
        #expect(session.hand.contains(replacement))
        #expect(session.engineState?.events == events)
        #expect(session.engineState?.rng == rng)
        #expect(casts.requests.isEmpty)
        #expect(retiredPresentation.hand.contains(card))

        let current = BattleFieldLane(
            configuration: configuration, presentationContext: context,
            battleSession: session, presentation: session.presentation,
            interactionState: BattleInteractionState(), castPresentation: casts,
        )
        #expect(current.playCard(replacement, request: request))
        #expect(!session.hand.contains(replacement))
    }

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

    @Test(arguments: [false, true])
    func `auto battle uses the normal tap cast while manual play remains available`(queued: Bool) throws {
        let session = makeSession()
        defer { session.endBattle() }
        let card = try install(.slash, in: session)
        var state = try #require(session.engineState)
        let next = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &state)
        let preceding = queued ? BattleCardCombatEngine.deal(.slash, owner: .companion, context: &state) : nil
        session.engineState = state
        session.installSimulationPresentation()
        if let preceding {
            #expect(session.playCard(cardID: preceding.id) == .committed)
        }
        session.isAutoBattleEnabled = true
        let casts = BattleCastPresentationState()
        defer { casts.reset() }
        let field = try makeField(in: session, casts: casts)
        let frame = BattleHandLayout.frame(in: CGSize(width: 375, height: 667))
        let expected = CardActivationRequest.tapRequest(
            for: card, index: 0, cardCount: session.hand.count, handFrame: frame,
        )
        #expect(field.playAutoBattleCard(card, handFrame: frame))
        #expect(!session.hand.contains(card))
        #expect(session.cardCues.current?.mode == .pressPreview)
        let automatic = try #require(casts.request)
        #expect(automatic.center == expected.center)
        #expect(automatic.size == expected.size)
        #expect(automatic.rotation == expected.rotation)
        #expect(automatic.verticalTilt == expected.verticalTilt)
        #expect(automatic.scale == expected.scale)
        #expect(automatic.perspective == expected.perspective)
        #expect(session.cardPlayback.handDeparture(id: automatic.id) == nil)
        #expect(automatic.completionDate(scheduledCast: nil) == automatic.startedAt.addingTimeInterval(BattleMotion.cardActivationDuration))

        #expect(session.canInteractWithHand)
        session.beginCardCue(next, mode: .pressPreview)
        let manual = CardActivationRequest.tapRequest(
            for: next, index: 0, cardCount: session.hand.count, handFrame: frame,
        )
        #expect(field.playCard(next, request: manual))
        #expect(session.hand.isEmpty)
        #expect(casts.requests.map(\.id) == [automatic.id, manual.id])
        #expect(session.cardPlayback.handDeparture(id: manual.id) == nil)
        if let preceding {
            _ = try state.playCard(cardID: preceding.id)
        }
        _ = try state.playCard(cardID: card.id)
        _ = try state.playCard(cardID: next.id)
        #expect(session.engineState?.events == state.events)
        #expect(session.engineState?.rng == state.rng)

        let pause = automatic.startedAt.addingTimeInterval(0.2)
        casts.setSuspended(true, at: pause)
        #expect(casts.blocksAutoBattle(at: pause.addingTimeInterval(10)))
        casts.setSuspended(false, at: pause.addingTimeInterval(10))
        let resumed = try #require(casts.requests.first)
        #expect(resumed.startedAt == automatic.startedAt.addingTimeInterval(10))
        #expect(resumed.completionDate(scheduledCast: nil) == automatic.completionDate(scheduledCast: nil).addingTimeInterval(10))

        session.isAutoBattleEnabled = false
        #expect(!field.playAutoBattleCard(card, handFrame: frame))
        casts.remove(id: automatic.id)
        #expect(casts.requests.map(\.id) == [manual.id])
    }

    @Test(arguments: [0, 1, 2], [CGSize(width: 375, height: 667), CGSize(width: 669, height: 869)])
    func `automatic tap geometry matches the held manual release`(index: Int, size: CGSize) throws {
        let session = makeSession()
        defer { session.endBattle() }
        let card = try install(.slash, in: session)
        let frame = BattleHandLayout.frame(in: size)
        let metrics = BattleHandLayout.metrics(containerWidth: frame.width, cardCount: 3, handHeight: frame.height)
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let auto = CardActivationRequest.tapRequest(for: card, index: index, cardCount: 3, handFrame: frame, startedAt: start)
        let manual = CardActivationRequest.handRequest(
            for: card,
            center: BattleHandLayout.releaseCenter(
                restingCenter: BattleHandLayout.restingCenter(index: index, metrics: metrics, cardCount: 3, handFrame: frame),
                dragTranslation: .zero,
                cardSize: CGSize(width: metrics.cardWidth, height: metrics.cardHeight),
                rotation: BattleHandLayout.rotation(index: index, cardCount: 3) * .pi / 180,
                scale: CGFloat(BattleMotion.cardHeldScale),
                in: frame,
            ),
            size: CGSize(width: metrics.cardWidth, height: metrics.cardHeight),
            rotation: BattleHandLayout.rotation(index: index, cardCount: 3) * .pi / 180,
            verticalTilt: 0,
            scale: CGFloat(BattleMotion.cardHeldScale),
            startedAt: start,
        )
        #expect(auto.center == manual.center)
        #expect(auto.size == manual.size)
        #expect(auto.rotation == manual.rotation)
        #expect(auto.verticalTilt == manual.verticalTilt)
        #expect(auto.scale == manual.scale)
        #expect(auto.perspective == manual.perspective)
        #expect(auto.keywords == manual.keywords)
        #expect(auto.completionDate(scheduledCast: nil) == manual.completionDate(scheduledCast: nil))
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

    private func makeField(in session: BattleSession, casts: BattleCastPresentationState) throws -> BattleFieldLane {
        try BattleFieldLane(
            configuration: #require(session.activeBattle),
            presentationContext: #require(session.presentationContext),
            battleSession: session, presentation: session.presentation,
            interactionState: BattleInteractionState(), castPresentation: casts,
        )
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

extension BattleSessionCardCueTests {
    @Test func `queued lift advances until its expected turn and preserves an early handoff`() throws {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let casts = BattleCastPresentationState()
        defer { casts.reset() }
        casts.append(CardActivationRequest(
            startedAt: start, artworkName: nil, center: .zero, size: .zero,
            rotation: 0, verticalTilt: 0, scale: 1, keywords: [],
        ))
        var handedOffProgress: CGFloat?
        casts.queueCard(id: 1, at: start) { _ in false }
        casts.queueCard(id: 2, at: start) { progress in
            handedOffProgress = progress
            return true
        }
        let first = try #require(casts.queuedCards.first)
        let second = try #require(casts.queuedCards.last)
        #expect(first.duration == BattleMotion.manualCardInterval)
        #expect(second.duration == 2 * BattleMotion.manualCardInterval)
        #expect(second.progress(at: start) == 0)
        #expect(second.progress(at: first.expectedStart) == 0.5)
        #expect(second.progress(at: second.expectedStart) == 1)
        casts.playNextQueuedCard(at: first.expectedStart)
        #expect(handedOffProgress == 0.5)

        let session = makeSession()
        defer { session.endBattle() }
        let card = try install(.slash, in: session)
        let frame = BattleHandLayout.frame(in: CGSize(width: 375, height: 667))
        let resting = CardActivationRequest.restingRequest(for: card, index: 0, cardCount: 3, handFrame: frame)
        let early = CardActivationRequest.queuedRequest(
            for: card, index: 0, cardCount: 3, handFrame: frame, liftProgress: 0.5,
        )
        #expect(early.center.x == resting.center.x)
        #expect(early.center.y == resting.center.y - resting.size.height * BattleMotion.queuedCardLiftFraction * 0.5)
        #expect(early.rotation == resting.rotation)
        #expect(early.scale == CGFloat(BattleMotion.cardHeldScale))
    }
}
