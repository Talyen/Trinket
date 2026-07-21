import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct EffectHandlersApplyBuffDebuffTests {
    // MARK: - Debuff

    @Test(arguments: [true, false])
    func halveShieldHandlerAppliesOnlyWhenBlockPresent(seedBlock: Bool) throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        if seedBlock {
            BattleStateTestFactory.seedActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 3), remainingTicks: 0)],
                for: battle.enemy,
                on: &battle
            )
        }
        let outcome = EffectHandlersTestSupport.dispatch(
            .halveShield(.block),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle
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

    @Test func burnHandlerDoesNotApplyToDefeatedTarget() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: enemy) { $0.currentHealth = 0 }
        }
        let outcome = EffectHandlersTestSupport.dispatch(
            .burn(3),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: enemy,
            battle: &battle
        )
        try #expect(!(outcome.didApply))
        try #expect(!(battle.activeEffects(of: battle.enemy).contains(where: \.effect.isDecayingDoT)))
    }

    @Test func cardCombatNoOpHandlersDoNotApply() throws {
        do {
            var battle = EffectHandlersTestSupport.makeBattle()
            let outcome = EffectHandlersTestSupport.dispatch(
                .deathsDoor,
                ability: CombatantFixtures.ability(),
                source: battle.hero,
                target: battle.hero,
                battle: &battle
            )
            try #expect(!(outcome.didApply))
            try #expect(outcome.events.isEmpty)
        }
    }

    // MARK: - Timed buffs

    @Test func thornsHandlerAppliesThornsAndEmitsEvent() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            primaryStats: PrimaryStats(strength: 20)
        )
        var battle = EffectHandlersTestSupport.makeBattle(hero: hero)
        let outcome = EffectHandlersTestSupport.dispatch(
            .thorns(.physical, 5, Effect.standardThornsDuration),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        let expectedAmount = 7
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.hero).contains { active in
            if case let .thorns(.physical, amount, duration) = active.effect {
                return amount == expectedAmount
                    && duration == Effect.standardThornsDuration
                    && active.remainingTicks == Effect.standardThornsDuration
            }
            return false
        })
        try #expect(outcome.events.contains {
            $0.effectKind == .thornsApplied && $0.amount == expectedAmount
        })
    }

    @Test func markedHandlerAppliesAndReplacesInsteadOfStacking() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let first = EffectHandlersTestSupport.dispatch(
            .marked(Effect.standardMarkedBonus, Effect.standardMarkedDuration),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle
        )
        try #expect(first.didApply)
        try #expect(battle.activeEffects(of: battle.enemy).contains { active in
            if case let .marked(bonus, duration) = active.effect {
                return bonus == Effect.standardMarkedBonus
                    && duration == Effect.standardMarkedDuration
                    && active.remainingTicks == Effect.standardMarkedDuration
            }
            return false
        })
        try #expect(first.events.contains {
            $0.effectKind == .markedApplied && $0.amount == Effect.standardMarkedBonus
        })

        let outcome = EffectHandlersTestSupport.dispatch(
            .marked(5, Effect.standardMarkedDuration),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle
        )
        try #expect(outcome.didApply)
        let marks = battle.activeEffects(of: battle.enemy).filter {
            if case .marked = $0.effect {
                return true
            }
            return false
        }
        try #expect(marks.count == 1)
        try #expect(marks.contains { active in
            if case let .marked(bonus, _) = active.effect {
                return bonus == 5
            }
            return false
        })
    }

    @Test func timedBuffHandlersApplyStackAndEmitEvent() throws {
        do {
            var battle = EffectHandlersTestSupport.makeBattle()
            let outcome = EffectHandlersTestSupport.dispatch(
                .criticalChanceBonus(0.15, 6),
                ability: CombatantFixtures.ability(),
                source: battle.hero,
                target: battle.hero,
                battle: &battle
            )
            try #expect(outcome.didApply)
            try #expect(battle.activeEffects(of: battle.hero).contains { active in
                if case let .criticalChanceBonus(percent, duration) = active.effect {
                    return percent == 0.15 && duration == 6 && active.remainingTicks == 6
                }
                return false
            })
            try #expect(outcome.events.contains {
                $0.effectKind == .criticalChanceApplied && $0.amount == 15
            })
        }

        do {
            var battle = EffectHandlersTestSupport.makeBattle()
            let outcome = EffectHandlersTestSupport.dispatch(
                .restoreManaOnHit(3, 6),
                ability: CombatantFixtures.ability(),
                source: battle.hero,
                target: battle.hero,
                battle: &battle
            )
            try #expect(outcome.didApply)
            try #expect(battle.activeEffects(of: battle.hero).contains { active in
                if case let .restoreManaOnHit(amount, duration) = active.effect {
                    return amount == 3 && duration == 6 && active.remainingTicks == 6
                }
                return false
            })
            try #expect(outcome.events.contains {
                $0.effectKind == .manaShieldApplied && $0.amount == 3 && $0.keyword == .mana
            })
        }

        do {
            var battle = EffectHandlersTestSupport.makeBattle()
            let outcome = EffectHandlersTestSupport.dispatch(
                .damageKeywordOverride(.holy, 3, 6),
                ability: CombatantFixtures.ability(),
                source: battle.hero,
                target: battle.hero,
                battle: &battle
            )
            try #expect(outcome.didApply)
            try #expect(battle.activeEffects(of: battle.hero).contains { active in
                if case let .damageKeywordOverride(keyword, bonus, duration) = active.effect {
                    return keyword == .holy && bonus == 3 && duration == 6 && active.remainingTicks == 6
                }
                return false
            })
            try #expect(outcome.events.contains {
                $0.effectKind == .damageKeywordOverrideApplied && $0.amount == 3 && $0.keyword == .holy
            })
        }
    }
}
