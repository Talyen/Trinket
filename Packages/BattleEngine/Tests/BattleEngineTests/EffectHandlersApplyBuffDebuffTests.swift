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
                [ActiveEffect(id: 1, effect: .shield(.block, 3), remainingTurns: 0)],
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

    @Test func doTEffectsCannotApplyToDefeatedTargets() {
        // Defeated-target exclusion is owned by the turn engine's apply gate,
        // which consults this per-effect contract; handlers rely on it.
        #expect(!Effect.burn(3).canApplyToDefeatedTarget)
        #expect(!Effect.poison(3).canApplyToDefeatedTarget)
        #expect(!Effect.bleed(3).canApplyToDefeatedTarget)
        #expect(!Effect.controlMeter(.freeze, 1, 1).canApplyToDefeatedTarget)
    }

    @Test func bleedHandlerReportsAppliedWhenPairedDamageSuppressesEvents() throws {
        // Paired direct damage skips the immediate hit, so no events fire even
        // though the bleed stack lands; didApply must track the stack.
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            .bleed(4),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            action: ActionApplyContext(pairedDirectDamage: [PairedDamage(keyword: .bleed, amount: 6)]),
            battle: &battle
        )
        try #expect(outcome.didApply)
        try #expect(outcome.events.isEmpty)
        try #expect(battle.activeEffects(of: battle.enemy).count(where: { $0.effect.isBleed }) == 1)
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
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            .thorns(5),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.hero).contains { active in
            if case let .thorns(amount) = active.effect {
                return amount == 5 && active.remainingTurns == 0
            }
            return false
        })
        try #expect(outcome.events.contains {
            $0.effectKind == .thornsApplied && $0.amount == 5
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
                    && active.remainingTurns == Effect.standardMarkedDuration
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

    @Test func criticalChanceBonusReapplyRefreshesSingleStack() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let ability = CombatantFixtures.ability()
        let first = EffectHandlersTestSupport.dispatch(
            .criticalChanceBonus(0.15, 6),
            ability: ability,
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(first.didApply)
        let second = EffectHandlersTestSupport.dispatch(
            .criticalChanceBonus(0.20, 4),
            ability: ability,
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(second.didApply)
        let focused = battle.activeEffects(of: battle.hero).filter {
            if case .criticalChanceBonus = $0.effect {
                return true
            }
            return false
        }
        try #expect(focused.count == 1)
        try #expect(focused.contains { active in
            if case let .criticalChanceBonus(percent, duration) = active.effect {
                return percent == 0.20 && duration == 4 && active.remainingTurns == 4
            }
            return false
        })
        try #expect(second.events.contains {
            $0.effectKind == .criticalChanceApplied && $0.amount == 20
        })
    }

    @Test func restoreManaOnHitHandlerAppliesStackAndEmitsEvent() throws {
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
                return amount == 3 && duration == 6 && active.remainingTurns == 6
            }
            return false
        })
        try #expect(outcome.events.contains {
            $0.effectKind == .manaShieldApplied && $0.amount == 3 && $0.keyword == .mana
        })
    }

    @Test func restoreManaOnHitRecastStacksOnTopOfExistingShield() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let ability = CombatantFixtures.ability()
        _ = EffectHandlersTestSupport.dispatch(
            .restoreManaOnHit(3, 6),
            ability: ability,
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        let second = EffectHandlersTestSupport.dispatch(
            .restoreManaOnHit(5, 4),
            ability: ability,
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(second.didApply)
        let shields = battle.activeEffects(of: battle.hero).filter {
            if case .restoreManaOnHit = $0.effect {
                return true
            }
            return false
        }
        // Recasts stack; each stack restores on hit.
        try #expect(shields.count == 2)
        try #expect(shields.contains { active in
            if case let .restoreManaOnHit(amount, duration) = active.effect {
                return amount == 5 && duration == 4 && active.remainingTurns == 4
            }
            return false
        })
    }

    @Test func damageKeywordOverrideHandlerAppliesStackAndEmitsEvent() throws {
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
                return keyword == .holy && bonus == 3 && duration == 6 && active.remainingTurns == 6
            }
            return false
        })
        try #expect(outcome.events.contains {
            $0.effectKind == .damageKeywordOverrideApplied && $0.amount == 3 && $0.keyword == .holy
        })
    }

    @Test func nextStrikeDoubleHandlerAppliesAndEmitsEvent() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            .nextStrikeDouble,
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.hero).contains { active in
            if case .nextStrikeDouble = active.effect {
                return true
            }
            return false
        })
        try #expect(outcome.events.contains { $0.effectKind == .nextStrikeDoubleApplied })
    }

    @Test func evadeNextHitHandlerAppliesAndEmitsEvent() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            .evadeNextHit,
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.hero).contains { active in
            if case .evadeNextHit = active.effect {
                return true
            }
            return false
        })
        try #expect(outcome.events.contains { $0.effectKind == .evadeNextHitApplied })
    }
}
