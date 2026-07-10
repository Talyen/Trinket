import Testing
import TrinketTestSupport
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct EffectHandlersApplyTests {
    // MARK: - DoT handlers

    @Test func burnHandlerAppliesBurnEffect() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        let outcome = EffectHandlersTestSupport.dispatch(.burn(3), ability: CombatantFixtures.ability(), source: battle.hero, target: enemy, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect.isDecayingDoT && $0.keyword == .burn })
    }

    @Test func burnHandlerSkipsInitialDamageWhenPaired() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        let hero = battle.hero
        let action = ActionApplyContext(pairedDirectDamage: [(.burn, 3)])
        let outcome: EffectApplyOutcome = try battle.withEngineContext { context in
            try #require(EffectHandlers.all[.burn]?.apply(
                .burn(3),
                ability: CombatantFixtures.ability(),
                source: hero,
                target: enemy,
                action: action,
                in: &context
            ))
        }
        try #expect(outcome.didApply)
        // No `events` containing a status DoT damage entry.
        try #expect(!(outcome.events.contains { $0.kind == .status && $0.keyword == .burn }))
    }

    @Test func poisonHandlerAppliesPoisonEffect() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.poison(2), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect.isDecayingDoT && $0.keyword == .poison })
    }

    @Test func bleedHandlerAppliesBleedEffect() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.bleed(2), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.enemy).contains(where: \.effect.isBleed))
    }

    // MARK: - Defensive buffs

    @Test func shieldHandlerAddsShieldAndEmitsEvent() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.shield(.block, 5, 3), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.hero).contains { ae in
            if case .shield(.block, 5, _) = ae.effect { return true }
            return false
        })
        try #expect(outcome.events.contains { $0.effectKind == .shieldApplied && $0.amount == 5 })
    }

    @Test func mitigationHandlerAddsMitigationAndEmitsEvent() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.mitigation(.armor, 0.25, 6), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.hero).contains { ae in
            if case .mitigation(.armor, 0.25, _) = ae.effect { return true }
            return false
        })
        try #expect(outcome.events.contains { $0.effectKind == .mitigationApplied && $0.amount == 25 })
    }

    @Test func leechHandlerAddsLeechEffectAndEmitsEvent() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.standardLeechBuff, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.hero).contains { $0.effect.keyword == .leech && !$0.effect.isInstant })
        try #expect(outcome.events.contains { $0.effectKind == .leechApplied })
    }

    @Test func leechHandlerReplacesExistingLeechInsteadOfStacking() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        _ = EffectHandlersTestSupport.dispatch(.standardLeechBuff, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        let outcome = EffectHandlersTestSupport.dispatch(.standardLeechBuff, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(outcome.didApply)
        let leechStacks = battle.activeEffects(of: battle.hero).filter { $0.effect.keyword == .leech }
        try #expect(leechStacks.count == 1)
    }

    @Test func cleanseWithoutDebuffsDoesNotApply() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(.poison), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(!(outcome.didApply))
        try #expect(outcome.events.isEmpty)
    }

    // MARK: - Restoration

    @Test func instantHealHandlerHealsTarget() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let hero = battle.hero
        _ = battle.withEngineContext { $0.applyTestDamage(30, to: hero) }
        let before = battle.health(of: battle.hero)
        let outcome = EffectHandlersTestSupport.dispatch(.instantHeal(.health, 5), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(battle.health(of: battle.hero) > before)
        try #expect(outcome.events.first?.amount == battle.health(of: battle.hero) - before)
    }

    @Test func instantHealHandlerDoesNotApplyAtFullHealth() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let hero = battle.hero
        let outcome = EffectHandlersTestSupport.dispatch(
            .instantHeal(.health, 5),
            ability: CombatantFixtures.ability(),
            source: hero,
            target: hero,
            battle: &battle
        )
        try #expect(!(outcome.didApply))
        try #expect(outcome.events.isEmpty)
    }

    @Test func resourceGainHandlerAddsGold() throws {
        var battle = EffectHandlersTestSupport.makeBattle(initialGold: 10)
        let resourceEffect: Effect = .resourceGain(.gold, 3)
        let outcome = EffectHandlersTestSupport.dispatch(resourceEffect, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(battle.gold == 13)
        try #expect(outcome.events.contains { $0.effectKind == .resourceGain && $0.amount == 3 })
    }

    // MARK: - Cleanse

    @Test func cleanseSpecificKeywordRemovesMatchingEffects() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)],
            for: battle.hero,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(.poison), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(!(battle.activeEffects(of: battle.hero)).contains { $0.effect.isDecayingDoT && $0.keyword == .poison })
        try #expect(outcome.events.contains { $0.effectKind == .cleanseApplied && $0.keyword == .poison })
    }

    @Test func cleanseAllRemovesAllDebuffs() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0),
                ActiveEffect(id: 3, effect: .shield(.block, 5, 6), remainingTicks: 6)
            ],
            for: battle.hero,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(nil), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(outcome.didApply)
        // Debuffs gone, shield still present
        try #expect(!(battle.activeEffects(of: battle.hero)).contains(where: \.effect.isRemovableDebuff))
        try #expect(battle.activeEffects(of: battle.hero).contains { $0.effect.isTickable && !$0.effect.isRemovableDebuff })
    }

    @Test func cleanseIsInstantAndLeavesNoActiveEffect() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)],
            for: battle.hero,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(.poison), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(!(battle.activeEffects(of: battle.hero)).contains { if case .cleanse = $0.effect { return true }; return false })
        try #expect(!(battle.activeEffects(of: battle.hero)).contains { $0.effect.isDecayingDoT && $0.keyword == .poison })
    }

    @Test func cleanseStunRemovesActivePrevention() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.stun, 5, 10), remainingTicks: 0)],
            for: battle.hero,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(.stun), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(!(battle.activeEffects(of: battle.hero)).contains(where: \.effect.isControlMeter))
    }

    @Test func cleanseRandomRemovesOneDebuff() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0)
            ],
            for: battle.hero,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.cleanseRandom, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(outcome.didApply)
        // Exactly one debuff removed
        let remainingDebuffs = battle.activeEffects(of: battle.hero).filter(\.effect.isRemovableDebuff)
        try #expect(remainingDebuffs.count == 1)
    }

    // MARK: - Purge

    @Test func purgeSpecificKeywordRemovesMatchingBuffs() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [
                ActiveEffect(id: 1, effect: .shield(.block, 5, 6), remainingTicks: 6),
                ActiveEffect(id: 2, effect: .mitigation(.armor, 0.25, 6), remainingTicks: 6)
            ],
            for: battle.enemy,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.purge(.block), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(!(battle.activeEffects(of: battle.enemy)).contains { if case .shield = $0.effect { return true }; return false })
        try #expect(battle.activeEffects(of: battle.enemy).contains { if case .mitigation = $0.effect { return true }; return false })
        try #expect(outcome.events.contains { $0.effectKind == .purgeApplied && $0.keyword == .block })
    }

    @Test func purgeAllRemovesBuffsButLeavesDebuffs() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [
                ActiveEffect(id: 1, effect: .shield(.block, 5, 6), remainingTicks: 6),
                ActiveEffect(id: 2, effect: .poison(4), remainingTicks: 0)
            ],
            for: battle.enemy,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.purge(nil), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(!(battle.activeEffects(of: battle.enemy)).contains(where: \.effect.isRemovableBuff))
        try #expect(battle.activeEffects(of: battle.enemy).contains(where: \.effect.isRemovableDebuff))
        try #expect(outcome.events.contains { $0.effectKind == .purgeApplied && $0.keyword == .purge })
    }

    @Test func purgeRandomRemovesOneBuff() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [
                ActiveEffect(id: 1, effect: .shield(.block, 5, 6), remainingTicks: 6),
                ActiveEffect(id: 2, effect: .mitigation(.armor, 0.25, 6), remainingTicks: 6)
            ],
            for: battle.enemy,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.purgeRandom, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.enemy).filter(\.effect.isRemovableBuff).count == 1)
        try #expect(outcome.events.contains { $0.effectKind == .purgeApplied })
    }

    // MARK: - Debuff

    @Test func halveMitigationHandlerHalvesArmorAndEmitsEvent() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .mitigation(.armor, 0.40, 6), remainingTicks: 6)],
            for: battle.enemy,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.halveMitigation(.armor), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.enemy).contains { ae in
            if case .mitigation(.armor, 0.20, _) = ae.effect { return true }
            return false
        })
        try #expect(outcome.events.contains { $0.effectKind == .mitigationHalved && $0.keyword == .armor })
    }

    @Test func halveMitigationHandlerReportsNoApplyWhenArmorMissing() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            .halveMitigation(.armor),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle
        )
        try #expect(!(outcome.didApply))
        try #expect(outcome.events.isEmpty)
    }

    @Test func controlMeterHandlerAppliesThroughPipeline() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.controlMeter(.stun, 1, 10), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.enemy).contains(where: \.effect.isControlMeter))
    }

    @Test func controlMeterHandlerDoesNotApplyWhenSameKeywordSkipPending() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)],
            for: battle.enemy,
            on: &battle
        )
        let effectsBefore = battle.activeEffects(of: battle.enemy)
        let outcome = EffectHandlersTestSupport.dispatch(
            .controlMeter(.stun, 5, 10),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle
        )
        try #expect(!(outcome.didApply))
        try #expect(outcome.events.isEmpty)
        try #expect(battle.activeEffects(of: battle.enemy) == effectsBefore)
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
        try #expect(!(battle.activeEffects(of: battle.enemy).contains { $0.effect.isDecayingDoT }))
    }

    @Test func deathsDoorHandlerApplyIsNoOp() throws {
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

    // MARK: - Timed buffs

    @Test func hasteHandlerIsNoOpInCardCombat() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            primaryStats: PrimaryStats(agility: 20)
        )
        var battle = EffectHandlersTestSupport.makeBattle(hero: hero)
        let outcome = EffectHandlersTestSupport.dispatch(
            .haste(Effect.standardHasteDuration),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        try #expect(!outcome.didApply)
        try #expect(!battle.activeEffects(of: battle.hero).contains { active in
            if case .haste = active.effect { return true }
            return false
        })
        try #expect(outcome.events.isEmpty)
    }

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

    @Test func markedHandlerAppliesMarkedAndEmitsEvent() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            .marked(Effect.standardMarkedBonus, Effect.standardMarkedDuration),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle
        )
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.enemy).contains { active in
            if case let .marked(bonus, duration) = active.effect {
                return bonus == Effect.standardMarkedBonus
                    && duration == Effect.standardMarkedDuration
                    && active.remainingTicks == Effect.standardMarkedDuration
            }
            return false
        })
        try #expect(outcome.events.contains {
            $0.effectKind == .markedApplied && $0.amount == Effect.standardMarkedBonus
        })
    }

    @Test func markedHandlerReplacesExistingMarkInsteadOfStacking() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        _ = EffectHandlersTestSupport.dispatch(
            .marked(2, Effect.standardMarkedDuration),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(
            .marked(5, Effect.standardMarkedDuration),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle
        )
        try #expect(outcome.didApply)
        let marks = battle.activeEffects(of: battle.enemy).filter {
            if case .marked = $0.effect { return true }
            return false
        }
        try #expect(marks.count == 1)
        try #expect(marks.contains { active in
            if case let .marked(bonus, _) = active.effect { return bonus == 5 }
            return false
        })
    }

    @Test func criticalChanceBonusHandlerAppliesBonusAndEmitsEvent() throws {
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

    @Test func restoreManaOnHitHandlerAppliesBuffAndEmitsEvent() throws {
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

    @Test func damageKeywordOverrideHandlerAppliesBuffAndEmitsEvent() throws {
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
