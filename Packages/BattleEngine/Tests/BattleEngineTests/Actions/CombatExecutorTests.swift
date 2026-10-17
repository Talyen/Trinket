import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CombatExecutorTests {
    @Test(arguments: [false, true])
    func `damage observation retains nested reactions independently of battle history`(tracksEvents: Bool) {
        var battle = BattleStateTestFactory.makeBattle(tracksEvents: tracksEvents, dealOpeningHand: false, appliesFightPacing: false)
        battle.insertEffect(.thorns(3), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        let start = battle.events.count
        let outcome = battle.recordingResult { context in context.resolveTestDamage(
            5,
            from: .enemy,
            to: .hero,
            options: .attack(accuracy: .unavoidable),
        ) }
        #expect(outcome.value.healthLost == 5)
        #expect(outcome.events.contains { $0.effectKind == .thornsTriggered })
        #expect(outcome.events.map(\.id) == outcome.events.map(\.id).sorted())
        #expect(Set(outcome.events.map(\.id)).count == outcome.events.count)
        if tracksEvents {
            #expect(outcome.events == Array(battle.events.dropFirst(start)))
        } else {
            #expect(battle.events.isEmpty)
        }
        #expect(battle.commandOutput == nil)
    }

    @Test func `Winter Wake preview cannot publish Guardian block into the live command`() {
        var battle = BattleStateTestFactory.makeBattle(
            heroModifiers: .withTriggers { $0.wintersWake = true }, companionModifiers: .withTriggers { $0.guardianHeroBlockFlat = 2 },
            dealOpeningHand: false,
            appliesFightPacing: false,
        )
        battle.insertEffect(.evadeNextHit, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        let start = battle.events.count
        let request = DamageRequest(
            amount: 10, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(),
        )
        let outcome = battle.recordingResult { context in
            await context.resolveDamage(request)
        }
        let events = outcome.events
        #expect(outcome.value.isDodged)
        #expect(events.contains { $0.abilityName == "Winter’s Wake" })
        #expect(!events.contains { $0.abilityName == "Guardian" })
        #expect(events == Array(battle.events.dropFirst(start)))
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.activeEffects(for: battle.hero)) == 0)
        #expect(battle.commandOutput == nil)
    }

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
        #expect(actual.recordings.flatMap(\.playedCards).count >= 3)
        #expect(actual.events.contains { $0.effectKind == .thornsTriggered })
        #expect(actual.depths.allSatisfy { $0 == 0 })
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
        let recordings: [BattleCommandResult]
    }

    private static func recordedBattle(seed: UInt64) throws -> BattleTrace {
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
            heroModifiers: profile, rngSeed: seed, tracksLog: true, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.heroDeck = CombatDeck(abilities: [chain, .slash])
        battle.companionDeck = CombatDeck(abilities: [.slash])
        battle.insertEffect(.thorns(3), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        battle.insertEffect(.thorns(2), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        let card = BattleCardCombatEngine.deal(chain, owner: .hero, context: &battle)
        let play = try battle.playCard(cardID: card.id, recordActions: true)
        let turn = battle.endTurn(recordActions: true)
        return BattleTrace(
            roster: [battle.roster.hero, battle.roster.companion, battle.roster.enemy],
            hand: battle.hand, decks: [battle.heroDeck, battle.companionDeck],
            events: battle.events, log: battle.log, rng: battle.rng,
            counters: [battle.turnCount, battle.actionCount, battle.gold, battle.nextEventID, battle.nextEffectID, battle.nextCardID],
            depths: [CombatResolution.Scope.damage, .dot, .draw, .heroReaction, .uniqueReaction, .talentReaction]
                .map { battle.resolution.depth($0) },
            recordings: [play, turn],
        )
    }
}
