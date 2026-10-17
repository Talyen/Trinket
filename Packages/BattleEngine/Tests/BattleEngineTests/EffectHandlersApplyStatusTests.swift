import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct EffectHandlersApplyStatusTests {
    private static let poison = ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0)
    private static let burn = ActiveEffect(id: 2, effect: .burn(4), remainingTurns: 0)
    private static let block = ActiveEffect(id: 3, effect: .shield(.block, 5), remainingTurns: 6)
    private static let thorns = ActiveEffect(id: 4, effect: .thorns(3), remainingTurns: 0)
    private static let stun = ActiveEffect(id: 5, effect: .controlMeter(.stun, 5, 10), remainingTurns: 0)

    @Test(arguments: [
        (Effect.cleanse(.poison), [Self.poison, Self.burn], [Self.burn], Set<Keyword>?.some([.poison])),
        (.cleanse(nil), [Self.poison, Self.burn, Self.block], [Self.block], nil),
        (.cleanse(.stun), [Self.stun], [], nil),
    ])
    private func `cleanse removes selected debuffs and preserves buffs`(
        effect: Effect, stacks: [ActiveEffect], remaining: [ActiveEffect], feedback: Set<Keyword>?,
    ) {
        var battle = BattleStateTestFactory.makeMinimalBattle()
        battle.seedActiveEffects(stacks, for: battle.hero)
        let outcome = EffectHandlersTestSupport.dispatch(
            effect, battle: &battle,
        )
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.hero) == remaining)
        if let feedback {
            #expect(Set(outcome.events.filter { $0.effectKind == .cleanseApplied }.map(\.keyword)) == feedback)
        }
    }

    @Test(arguments: [
        (Effect.purge(.block), [Self.block, Self.thorns], [Self.thorns], Set([Keyword.block])),
        (.purge(nil), [Self.block, Self.poison], [Self.poison], Set([Keyword.block])),
        (.purge(nil), [Self.block, Self.thorns], [], Set([Keyword.block, .thorns])),
    ])
    private func `purge removes selected buffs and emits per-keyword feedback`(
        effect: Effect, stacks: [ActiveEffect], remaining: [ActiveEffect], feedback: Set<Keyword>,
    ) {
        var battle = BattleStateTestFactory.makeMinimalBattle()
        battle.seedActiveEffects(stacks, for: battle.enemy)
        let outcome = EffectHandlersTestSupport.dispatch(
            effect, target: battle.enemy, battle: &battle,
        )
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.enemy) == remaining)
        let events = outcome.events.filter { $0.effectKind == .purgeApplied }
        #expect(events.count == feedback.count)
        #expect(Set(events.map(\.keyword)) == feedback)
    }

    @Test(arguments: [false, true])
    func `random removal removes one eligible effect`(purge: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle()
        let target = purge ? battle.enemy : battle.hero
        let stacks = purge ? [Self.block, Self.thorns] : [Self.poison, Self.burn]
        battle.seedActiveEffects(stacks, for: target)
        let outcome = EffectHandlersTestSupport.dispatch(
            purge ? .purgeRandom : .cleanseRandom, target: target, battle: &battle,
        )
        #expect(outcome.didApply)
        let remaining = battle.activeEffects(of: target)
        #expect(remaining.count == 1)
        #expect(remaining.allSatisfy { stacks.contains($0) })
        if purge {
            #expect(outcome.events.contains { $0.effectKind == .purgeApplied })
        }
    }

    @Test func `intercepted timed debuff reports not applied`() throws {
        let warded = CombatModifierProfile.withTriggers { $0.blockFirstDebuffPerTurn = true }
        // Fae Ward lives on the target's own profile: seed the debuff target as hero with ward.
        var battle = BattleStateTestFactory.makeBattle(
            heroModifiers: warded,
            dealOpeningHand: false,
        )
        let outcome = EffectHandlersTestSupport.dispatch(
            .damageReductionFlat(2, 2),
            source: battle.enemy,
            battle: &battle,
        )
        try #expect(!outcome.didApply)
        try #expect(!battle.activeEffects(of: battle.hero).contains(where: \.effect.isRemovableDebuff))
    }
}
