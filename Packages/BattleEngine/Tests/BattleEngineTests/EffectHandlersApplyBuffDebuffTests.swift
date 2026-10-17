import Foundation
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct EffectHandlersApplyBuffDebuffTests {
    @Test(arguments: [Effect.maximumManaBonus(1), .restoreManaOnHit(3, 6)])
    func `Interdict prevents rejected Mana buffs from restoring Mana or reporting success`(effect: Effect) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxMana: 8),
            enemyModifiers: .withTriggers { $0.interdict = true },
        )
        _ = EffectHandlersTestSupport.dispatch(effect, battle: &battle)
        let purge = EffectHandlersTestSupport.dispatch(.purge(nil), source: battle.enemy, battle: &battle)
        #expect(purge.didApply)
        battle.roster.hero.currentMana = 0

        let rejected = EffectHandlersTestSupport.dispatch(effect, battle: &battle)

        #expect(!rejected.didApply)
        #expect(rejected.events.isEmpty)
        #expect(battle.roster.hero.activeEffects.isEmpty)
        #expect(battle.roster.hero.currentMana == 0)
        #expect(battle.roster.hero.maxMana == 8)
    }

    @Test func `a capped Block grant preserves its preparation without success feedback`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(appliesFightPacing: false)
        DefensePoolEngine.set(Int.max, on: battle.hero, in: &battle)
        battle.roster.hero.talents.pending.nextBlockGainMultiplier = PreparedTalentBonus(value: 2)
        let before = battle.roster.hero.activeEffects

        let outcome = EffectHandlersTestSupport.dispatch(.shield(.block, 1), battle: &battle)

        #expect(!outcome.didApply)
        #expect(outcome.events.isEmpty)
        #expect(battle.roster.hero.activeEffects == before)
        #expect(battle.roster.hero.talents.pending.nextBlockGainMultiplier?.value == 2)
    }

    @Test func `next attack conversion preserves its keyword and is consumed once`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 500, dealOpeningHand: false)
        let conversion = Effect.nextStrikeDamageKeywordOverride(.burn)
        for _ in 0 ..< 2 {
            let outcome = EffectHandlersTestSupport.dispatch(
                conversion, battle: &battle,
            )
            #expect(outcome.didApply)
            #expect(outcome.events.contains { $0.effectKind == .damageKeywordOverrideApplied && $0.keyword == .burn })
        }
        let effects = battle.activeEffects(of: battle.hero)
        #expect(effects.count { $0.effect == conversion } == 1)
        let summary = try #require(EffectSummaryBuilder.build(for: effects).first)
        #expect(summary.keyword == .burn)
        #expect(summary.text.contains(Keyword.burn.rawValue))

        let converted = battle.performTestAction(.slash)
        #expect(converted.filter { $0.kind == .abilityDamage }.map(\.keyword) == [.burn])
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.effect == conversion })
        let following = battle.performTestAction(.slash)
        #expect(following.filter { $0.kind == .abilityDamage }.map(\.keyword) == [.physical])
    }

    @Test func `status summary order is independent of effect insertion order`() {
        let keywords: [Keyword] = [.burn, .freeze, .holy]
        let effects = keywords.enumerated().map { index, keyword in
            ActiveEffect(id: index, effect: .onHitDamage(keyword, 2), remainingTurns: 0)
        }
        for order in [effects, Array(effects.reversed()), [effects[1], effects[2], effects[0]]] {
            #expect(EffectSummaryBuilder.build(for: order).map(\.keyword) == keywords)
        }
    }

    @Test(arguments: [
        ([Effect.damageReductionPercent(0.25, 3), .damageReductionPercent(0.20, 3)], "40%"),
        ([Effect.damageReductionFlat(2, 3), .damageReductionFlat(3, 3)], "by 5,"),
        (
            [Effect.damageReductionFlat(Int.max, 3), .damageReductionFlat(1, 3)],
            "by \(Int.max.formatted(.number.locale(Locale(identifier: "en")))),",
        ),
        ([Effect.healingReductionPercent(0.20, 3), .healingReductionPercent(0.50, 3)], "50%"),
    ])
    func `debuff summaries reflect combined combat penalties`(effects: [Effect], expected: String) throws {
        let stacks = effects.enumerated().map {
            ActiveEffect(id: $0.offset, effect: $0.element, remainingTurns: $0.element.durationTurns)
        }
        let summary = try #require(EffectSummaryBuilder.build(for: stacks).first)
        #expect(summary.text.contains(expected))
    }

    @Test func `indefinite buff summaries omit zero-turn duration`() {
        let stacks = [
            ActiveEffect(id: 1, effect: .criticalChanceBonus(0.25, 0), remainingTurns: 0),
            ActiveEffect(id: 2, effect: .restoreManaOnHit(1, 0), remainingTurns: 0),
            ActiveEffect(id: 3, effect: .damageKeywordOverride(.holy, 2, 0), remainingTurns: 0),
        ]
        let texts = EffectSummaryBuilder.build(for: stacks).map(\.text)
        #expect(texts.count == 3)
        #expect(!texts.joined(separator: " ").contains("0 turns left"))
    }

    @Test func `timed buff summaries keep remaining duration`() {
        let stacks = [ActiveEffect(id: 1, effect: .criticalChanceBonus(0.25, 2), remainingTurns: 2)]
        #expect(EffectSummaryBuilder.build(for: stacks).first?.text.contains("2 turns left") == true)
    }

    @Test(arguments: [Effect.purge(nil), .purgeRandom])
    func `purging maximum mana clamps remaining mana`(_ purge: Effect) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroMaxMana: 8)
        _ = EffectHandlersTestSupport.dispatch(
            .maximumManaBonus(1),
            battle: &battle,
        )
        #expect(battle.mana(of: battle.hero) == 9)

        let outcome = EffectHandlersTestSupport.dispatch(
            purge,
            source: battle.enemy,
            battle: &battle,
        )

        #expect(outcome.didApply)
        #expect(battle.maxMana(of: battle.hero) == 8)
        #expect(battle.mana(of: battle.hero) == 8)
    }

    @Test(arguments: [true, false])
    func `halve shield handler applies only when block present`(seedBlock: Bool) throws {
        var battle = BattleStateTestFactory.makeBattle()
        if seedBlock {
            battle.seedActiveEffects([ActiveEffect(id: 1, effect: .shield(.block, 3), remainingTurns: 0)], for: battle.enemy)
        }
        let outcome = EffectHandlersTestSupport.dispatch(
            .halveShield(.block),
            target: battle.enemy,
            battle: &battle,
        )
        if seedBlock {
            try #expect(outcome.didApply)
            try #expect(battle.activeEffects(of: battle.enemy).contains { ae in
                if case .shield(.block, 1) = ae.effect {
                    return true
                }
                return false
            })
            try #expect(outcome.events.contains { $0.effectKind == .shieldHalved && $0.keyword == .block })
        } else {
            try #expect(!(outcome.didApply))
            try #expect(outcome.events.isEmpty)
        }
    }

    @Test(arguments: [Effect.deathsDoor, .cleanse(.poison)])
    func `effects without eligible state do not apply`(effect: Effect) {
        var battle = BattleStateTestFactory.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(effect, battle: &battle)
        #expect(!outcome.didApply)
        #expect(outcome.events.isEmpty)
    }

    @Test(arguments: [
        (Effect.thorns(5), ActionEvent.EffectOutcome.thornsApplied, 5, Keyword.thorns, 0),
        (.damageKeywordOverride(.holy, 3, 6), .damageKeywordOverrideApplied, 3, .holy, 6),
    ])
    func `buff application retains magnitude duration and feedback`(
        effect: Effect, eventKind: ActionEvent.EffectOutcome, amount: Int, keyword: Keyword, turns: Int,
    ) {
        var battle = BattleStateTestFactory.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            effect, battle: &battle,
        )
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == effect && $0.remainingTurns == turns })
        #expect(outcome.events.contains { $0.effectKind == eventKind && $0.amount == amount && $0.keyword == keyword })
    }

    @Test(arguments: [
        (
            Effect.marked(Effect.standardMarkedBonus, Effect.standardMarkedDuration), Effect.marked(5, Effect.standardMarkedDuration),
            BattleParticipant.enemy, ActionEvent.EffectOutcome.markedApplied, Effect.standardMarkedBonus, 5,
        ),
        (.criticalChanceBonus(0.15, 6), .criticalChanceBonus(0.20, 4), .hero, .criticalChanceApplied, 15, 20),
    ])
    func `reapplying a replacing effect refreshes its only stack and feedback`(
        initial: Effect, replacement: Effect, recipient: BattleParticipant,
        event: ActionEvent.EffectOutcome, initialAmount: Int, replacementAmount: Int,
    ) {
        var battle = BattleStateTestFactory.makeBattle()
        let target = battle.roster[recipient].combatant
        for (effect, amount) in [(initial, initialAmount), (replacement, replacementAmount)] {
            let outcome = EffectHandlersTestSupport.dispatch(effect, target: target, battle: &battle)
            #expect(outcome.didApply)
            let stacks = battle.activeEffects(of: target).filter { $0.effect.kind == initial.kind }
            #expect(stacks.map(\.effect) == [effect])
            #expect(stacks.map(\.remainingTurns) == [effect.durationTurns])
            #expect(outcome.events.contains { $0.effectKind == event && $0.amount == amount })
        }
    }

    @Test func `restore mana on hit recast stacks on top of existing shield`() {
        var battle = BattleStateTestFactory.makeBattle()
        let first = EffectHandlersTestSupport.dispatch(
            .restoreManaOnHit(3, 6), battle: &battle,
        )
        #expect(first.didApply)
        #expect(first.events.contains { $0.effectKind == .manaShieldApplied && $0.amount == 3 && $0.keyword == .mana })
        let second = EffectHandlersTestSupport.dispatch(
            .restoreManaOnHit(5, 4), battle: &battle,
        )
        #expect(second.didApply)
        let shields = battle.activeEffects(of: battle.hero).filter { $0.effect.kind == .restoreManaOnHit }
        #expect(shields.map(\.effect) == [.restoreManaOnHit(3, 6), .restoreManaOnHit(5, 4)])
        #expect(shields.map(\.remainingTurns) == [6, 4])
    }

    @Test(arguments: [
        (Effect.nextBurnBonus(1), Effect.nextBurnBonus(2), ActionEvent.EffectOutcome.nextBurnBonusApplied, Keyword.burn, 2),
        (.thorns(1), .thorns(2), .thornsApplied, .thorns, 2),
        (.nextBurnBonus(Int.max / 2 + 1), .nextBurnBonus(Int.max), .nextBurnBonusApplied, .burn, Int.max),
        (.thorns(Int.max / 2 + 1), .thorns(Int.max), .thornsApplied, .thorns, Int.max),
    ])
    func `amount buffs stack once and saturate their state event and summary`(
        effect: Effect, expected: Effect, event: ActionEvent.EffectOutcome, keyword: Keyword, total: Int,
    ) {
        var battle = BattleStateTestFactory.makeBattle()
        let first = EffectHandlersTestSupport.dispatch(effect, battle: &battle)
        let second = EffectHandlersTestSupport.dispatch(effect, battle: &battle)
        #expect(first.didApply && second.didApply)
        #expect(battle.activeEffects(of: battle.hero).filter { $0.effect.kind == effect.kind }.map(\.effect) == [expected])
        #expect(second.events.last { $0.effectKind == event && $0.keyword == keyword }?.amount == total)
        let rawStacks = [ActiveEffect(id: 1, effect: effect, remainingTurns: 0), ActiveEffect(id: 2, effect: effect, remainingTurns: 0)]
        let displayedTotal = total.formatted(.number.locale(Locale(identifier: "en")))
        #expect(EffectSummaryBuilder.build(for: rawStacks).first?.text.contains(displayedTotal) == true)
    }
}
