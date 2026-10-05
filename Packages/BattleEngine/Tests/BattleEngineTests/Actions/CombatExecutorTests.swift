import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CombatExecutorTests {
    @Test func `deep continuations unwind in order on a small caller stack`() async throws {
        let trace = try await Self.onSmallStack {
            let caller = Thread.current
            var order: [Int] = []
            var stayedOnCaller = true
            let sum = CombatExecutor.run {
                await Self.retainFrames(4096, order: &order, stayedOnCaller: &stayedOnCaller, caller: caller)
            }
            return (sum, order, stayedOnCaller)
        }
        #expect(trace.0 == 4096 * 4097 / 2)
        #expect(trace.1 == Array((1 ... 4096).reversed()) + (1 ... 4096).map { -$0 })
        #expect(trace.2)
    }

    @Test func `seeded card chains retain battle and recording results on a small stack`() async throws {
        let expected = try Self.recordedBattle(seed: 77)
        let actual = try await Self.onSmallStack { try Self.recordedBattle(seed: 77) }
        #expect(actual == expected)
        #expect(actual.stayedOnCaller)
        #expect(actual.recordings.count {
            if case .cardPlayed = $0.checkpoint {
                true
            } else {
                false
            }
        } >= 3)
        #expect(actual.events.contains { $0.effectKind == .thornsTriggered })
        #expect(actual.depths.allSatisfy { $0 == 0 })
    }

    @MainActor
    @Test func `synchronous battle recording retains main actor access`() throws {
        let trace = try Self.recordedBattle(seed: 77, checkingIsolation: { MainActor.assertIsolated() })
        #expect(!trace.recordings.isEmpty)
    }

    private static func retainFrames(
        _ depth: Int,
        order: inout [Int],
        stayedOnCaller: inout Bool,
        caller: Thread,
    ) async -> Int {
        await CombatExecutor.suspend()
        stayedOnCaller = stayedOnCaller && matchesCaller(caller)
        guard depth > 0 else { return 0 }
        order.append(depth)
        let child = await retainFrames(depth - 1, order: &order, stayedOnCaller: &stayedOnCaller, caller: caller)
        order.append(-depth)
        return depth + child
    }

    private static func matchesCaller(_ caller: Thread) -> Bool {
        Thread.current === caller
    }

    private static func onSmallStack<Value: Sendable>(
        _ body: @escaping @Sendable () throws -> Value,
    ) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            let thread = Thread {
                do { try continuation.resume(returning: body()) }
                catch { continuation.resume(throwing: error) }
            }
            thread.stackSize = 512 * 1024
            thread.start()
        }
    }

    private struct Recording: Equatable {
        let checkpoint: BattleTransitionCheckpoint
        let roster: [CombatantRuntime]
        let hand: BattleHand
        let events: [ActionEvent]
        let rng: SeededRandomNumberGenerator
    }

    // Concurrency-Safety: immutable value/CoW snapshots transfer only after the producer's command completes; no recorder is retained.
    private struct BattleTrace: Equatable, @unchecked Sendable {
        let roster: [CombatantRuntime]
        let hand: BattleHand
        let decks: [CombatDeck]
        let events: [ActionEvent]
        let log: [LogEntry]
        let rng: SeededRandomNumberGenerator
        let counters: [Int]
        let depths: [Int]
        let recordings: [Recording]
        let stayedOnCaller: Bool
    }

    private static func recordedBattle(seed: UInt64, checkingIsolation: @escaping () -> Void = {}) throws -> BattleTrace {
        let chain = Ability(
            id: "executor-chain", name: "Chain", tier: .basic,
            targetedEffects: [TargetedEffect(.drawAndPlayCards(2), target: .actor)],
        )
        var profile = CombatModifierProfile.zero
        let spiteful = try #require(GameContent.itemAffixDefinition(matching: "spiteful"))
        spiteful.basic.triggers.apply(to: &profile, abilityName: spiteful.title)
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [chain, .slash], companionAbilities: [.slash], enemyAbilities: [.slash],
            heroMaxHealth: 100, companionMaxHealth: 100, enemyMaxHealth: 2000,
            heroModifiers: profile, rngSeed: seed, tracksLog: true, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.heroDeck = CombatDeck(abilities: [chain, .slash])
        battle.companionDeck = CombatDeck(abilities: [.slash])
        battle.appendEffect(.thorns(3), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        battle.appendEffect(.thorns(2), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        let card = BattleCardCombatEngine.deal(chain, owner: .hero, context: &battle)
        let caller = Thread.current
        var recordings: [Recording] = []
        var stayedOnCaller = true
        let record: (BattleTransitionCheckpoint, BattleState, [ActionEvent]) -> Void = { checkpoint, state, events in
            checkingIsolation()
            stayedOnCaller = stayedOnCaller && matchesCaller(caller)
            recordings.append(Recording(
                checkpoint: checkpoint, roster: [state.roster.hero, state.roster.companion, state.roster.enemy],
                hand: state.hand, events: events, rng: state.rng,
            ))
        }
        _ = try battle.playCard(cardID: card.id, recording: record)
        _ = battle.endTurn(recording: record)
        return BattleTrace(
            roster: [battle.roster.hero, battle.roster.companion, battle.roster.enemy],
            hand: battle.hand, decks: [battle.heroDeck, battle.companionDeck],
            events: battle.events, log: battle.log, rng: battle.rng,
            counters: [battle.turnCount, battle.actionCount, battle.gold, battle.nextEventID, battle.nextEffectID, battle.nextCardID],
            depths: [CombatResolution.Scope.damage, .dot, .draw, .heroReaction, .uniqueReaction, .talentReaction]
                .map { battle.resolution.depth($0) },
            recordings: recordings, stayedOnCaller: stayedOnCaller,
        )
    }
}
