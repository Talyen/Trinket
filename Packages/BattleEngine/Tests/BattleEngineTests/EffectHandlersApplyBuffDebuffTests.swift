import BattleEngine
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

struct EffectHandlersApplyBuffDebuffTests {
    @Test func `next attack conversion preserves its keyword and is consumed once`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 500, dealOpeningHand: false)
        let conversion = Effect.nextStrikeDamageKeywordOverride(.burn)
        for _ in 0 ..< 2 {
            let outcome = EffectHandlersTestSupport.dispatch(
                conversion, source: battle.hero, target: battle.hero, battle: &battle,
            )
            #expect(outcome.didApply)
            #expect(outcome.events.contains { $0.effectKind == .damageKeywordOverrideApplied && $0.keyword == .burn })
        }
        let effects = battle.activeEffects(of: battle.hero)
        #expect(effects.count { $0.effect == conversion } == 1)
        let summary = try #require(EffectSummaryBuilder.build(for: effects).first)
        #expect(summary.keyword == .burn)
        #expect(summary.text.contains(Keyword.burn.rawValue))

        let converted = BattleTurnEngine.performAction(
            ability: .slash, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(converted.filter { $0.kind == .abilityDamage }.map(\.keyword) == [.burn])
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.effect == conversion })
        let following = BattleTurnEngine.performAction(
            ability: .slash, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
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
        ([Effect.healingReductionPercent(0.20, 3), .healingReductionPercent(0.50, 3)], "50%"),
    ])
    func `debuff summaries reflect combined combat penalties`(effects: [Effect], expected: String) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        for effect in effects {
            _ = EffectHandlersTestSupport.dispatch(effect, source: battle.hero, target: battle.enemy, battle: &battle)
        }
        let summary = try #require(EffectSummaryBuilder.build(for: battle.activeEffects(of: battle.enemy)).first)
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
            source: battle.hero,
            target: battle.hero,
            battle: &battle,
        )
        #expect(battle.mana(of: battle.hero) == 9)

        let outcome = EffectHandlersTestSupport.dispatch(
            purge,
            source: battle.enemy,
            target: battle.hero,
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
            BattleStateTestFactory.seedActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 3), remainingTurns: 0)],
                for: battle.enemy,
                on: &battle,
            )
        }
        let outcome = EffectHandlersTestSupport.dispatch(
            .halveShield(.block),
            source: battle.hero,
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

    @Test func `do T effects cannot apply to defeated targets`() {
        #expect(!Effect.burn(3).canApplyToDefeatedTarget)
        #expect(!Effect.poison(3).canApplyToDefeatedTarget)
        #expect(!Effect.bleed(3).canApplyToDefeatedTarget)
        #expect(!Effect.controlMeter(.freeze, 1, 1).canApplyToDefeatedTarget)
    }

    @Test func `card combat no op handlers do not apply`() throws {
        do {
            var battle = BattleStateTestFactory.makeBattle()
            let outcome = EffectHandlersTestSupport.dispatch(
                .deathsDoor,
                source: battle.hero,
                target: battle.hero,
                battle: &battle,
            )
            try #expect(!(outcome.didApply))
            try #expect(outcome.events.isEmpty)
        }
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
            effect, source: battle.hero, target: battle.hero, battle: &battle,
        )
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == effect && $0.remainingTurns == turns })
        #expect(outcome.events.contains { $0.effectKind == eventKind && $0.amount == amount && $0.keyword == keyword })
    }

    @Test func `marked handler applies and replaces instead of stacking`() throws {
        var battle = BattleStateTestFactory.makeBattle()
        let first = EffectHandlersTestSupport.dispatch(
            .marked(Effect.standardMarkedBonus, Effect.standardMarkedDuration),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle,
        )
        try #expect(first.didApply)
        try #expect(battle.activeEffects(of: battle.enemy).contains { active in
            if case let .marked(bonus, duration) = active.effect {
                return bonus == Effect.standardMarkedBonus
                    && duration == Effect.standardMarkedDuration
                    && active.remainingTurns == Effect.standardMarkedDuration
            }
            return false
        })
        try #expect(first.events.contains {
            $0.effectKind == .markedApplied && $0.amount == Effect.standardMarkedBonus
        })

        let outcome = EffectHandlersTestSupport.dispatch(
            .marked(5, Effect.standardMarkedDuration),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle,
        )
        try #expect(outcome.didApply)
        let marks = battle.activeEffects(of: battle.enemy).filter { $0.effect.kind == .marked }
        #expect(marks.map(\.effect) == [.marked(5, Effect.standardMarkedDuration)])
    }

    @Test func `critical chance bonus reapply refreshes single stack`() throws {
        var battle = BattleStateTestFactory.makeBattle()
        let first = EffectHandlersTestSupport.dispatch(
            .criticalChanceBonus(0.15, 6),
            source: battle.hero,
            target: battle.hero,
            battle: &battle,
        )
        try #expect(first.didApply)
        let second = EffectHandlersTestSupport.dispatch(
            .criticalChanceBonus(0.20, 4),
            source: battle.hero,
            target: battle.hero,
            battle: &battle,
        )
        try #expect(second.didApply)
        let focused = battle.activeEffects(of: battle.hero).filter { $0.effect.kind == .criticalChanceBonus }
        #expect(focused.map(\.effect) == [.criticalChanceBonus(0.20, 4)])
        #expect(focused.map(\.remainingTurns) == [4])
        try #expect(second.events.contains {
            $0.effectKind == .criticalChanceApplied && $0.amount == 20
        })
    }

    @Test func `restore mana on hit recast stacks on top of existing shield`() {
        var battle = BattleStateTestFactory.makeBattle()
        let first = EffectHandlersTestSupport.dispatch(
            .restoreManaOnHit(3, 6), source: battle.hero, target: battle.hero, battle: &battle,
        )
        #expect(first.didApply)
        #expect(first.events.contains { $0.effectKind == .manaShieldApplied && $0.amount == 3 && $0.keyword == .mana })
        let second = EffectHandlersTestSupport.dispatch(
            .restoreManaOnHit(5, 4), source: battle.hero, target: battle.hero, battle: &battle,
        )
        #expect(second.didApply)
        let shields = battle.activeEffects(of: battle.hero).filter { $0.effect.kind == .restoreManaOnHit }
        #expect(shields.map(\.effect) == [.restoreManaOnHit(3, 6), .restoreManaOnHit(5, 4)])
        #expect(shields.map(\.remainingTurns) == [6, 4])
    }

    @Test func `next burn bonus handler stacks and emits event`() throws {
        var battle = BattleStateTestFactory.makeBattle()
        let first = EffectHandlersTestSupport.dispatch(
            .nextBurnBonus(1),
            source: battle.hero,
            target: battle.hero,
            battle: &battle,
        )
        try #expect(first.didApply)
        let second = EffectHandlersTestSupport.dispatch(
            .nextBurnBonus(1),
            source: battle.hero,
            target: battle.hero,
            battle: &battle,
        )
        try #expect(second.didApply)
        try #expect(battle.activeEffects(of: battle.hero).contains { active in
            if case let .nextBurnBonus(amount) = active.effect {
                return amount == 2
            }
            return false
        })
        try #expect(second.events.contains {
            $0.effectKind == .nextBurnBonusApplied && $0.amount == 2 && $0.keyword == .burn
        })
    }
}
