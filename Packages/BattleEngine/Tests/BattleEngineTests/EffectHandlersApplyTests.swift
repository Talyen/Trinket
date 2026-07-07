import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct EffectHandlersApplyTests {
    // MARK: - DoT handlers

    @Test func burnHandlerAppliesBurnEffect() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        let outcome = EffectHandlersTestSupport.dispatch(.burn(3), ability: CombatantFixtures.ability(), source: battle.hero, target: enemy, battle: &battle)
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect.isDecayingDoT && $0.keyword == .burn })
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
        #expect(outcome.didApply)
        // No `events` containing a status DoT damage entry.
        #expect(!(outcome.events.contains { $0.kind == .status && $0.keyword == .burn }))
    }

    @Test func poisonHandlerAppliesPoisonEffect() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.poison(2), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect.isDecayingDoT && $0.keyword == .poison })
    }

    @Test func bleedHandlerAppliesBleedEffect() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.bleed(2), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.enemy).contains(where: \.effect.isBleed))
    }

    // MARK: - Defensive buffs

    @Test func shieldHandlerAddsShieldAndEmitsEvent() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.shield(.block, 5, 3), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.hero).contains { ae in
            if case .shield(.block, 5, _) = ae.effect { return true }
            return false
        })
        #expect(outcome.events.contains { $0.effectKind == .shieldApplied && $0.amount == 5 })
    }

    @Test func mitigationHandlerAddsMitigationAndEmitsEvent() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.mitigation(.armor, 0.25, 6), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.hero).contains { ae in
            if case .mitigation(.armor, 0.25, _) = ae.effect { return true }
            return false
        })
        #expect(outcome.events.contains { $0.effectKind == .mitigationApplied && $0.amount == 25 })
    }

    @Test func leechHandlerAddsLeechEffectAndEmitsEvent() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.standardLeechBuff, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect.keyword == .leech && !$0.effect.isInstant })
        #expect(outcome.events.contains { $0.effectKind == .leechApplied })
    }

    @Test func leechHandlerReplacesExistingLeechInsteadOfStacking() {
        var battle = EffectHandlersTestSupport.makeBattle()
        _ = EffectHandlersTestSupport.dispatch(.standardLeechBuff, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        let outcome = EffectHandlersTestSupport.dispatch(.standardLeechBuff, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        #expect(outcome.didApply)
        let leechStacks = battle.activeEffects(of: battle.hero).filter { $0.effect.keyword == .leech }
        #expect(leechStacks.count == 1)
    }

    @Test func cleanseWithoutDebuffsDoesNotApply() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(.poison), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        #expect(!(outcome.didApply))
        #expect(outcome.events.isEmpty)
    }

    // MARK: - Restoration

    @Test func instantHealHandlerHealsTarget() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let hero = battle.hero
        _ = battle.withEngineContext { $0.applyTestDamage(30, to: hero) }
        let before = battle.health(of: battle.hero)
        let outcome = EffectHandlersTestSupport.dispatch(.instantHeal(.health, 5), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        #expect(outcome.didApply)
        #expect(battle.health(of: battle.hero) > before)
        #expect(outcome.events.first?.amount == battle.health(of: battle.hero) - before)
    }

    @Test func instantHealHandlerDoesNotApplyAtFullHealth() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let hero = battle.hero
        let outcome = EffectHandlersTestSupport.dispatch(
            .instantHeal(.health, 5),
            ability: CombatantFixtures.ability(),
            source: hero,
            target: hero,
            battle: &battle
        )
        #expect(!(outcome.didApply))
        #expect(outcome.events.isEmpty)
    }

    @Test func resourceGainHandlerAddsGold() {
        var battle = EffectHandlersTestSupport.makeBattle(initialGold: 10)
        let resourceEffect: Effect = .resourceGain(.gold, 3)
        let outcome = EffectHandlersTestSupport.dispatch(resourceEffect, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        #expect(outcome.didApply)
        #expect(battle.gold == 13)
        #expect(outcome.events.contains { $0.effectKind == .resourceGain && $0.amount == 3 })
    }

    // MARK: - Cleanse

    @Test func cleanseSpecificKeywordRemovesMatchingEffects() {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)],
            for: battle.hero,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(.poison), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        #expect(outcome.didApply)
        #expect(!(battle.activeEffects(of: battle.hero)).contains { $0.effect.isDecayingDoT && $0.keyword == .poison })
        #expect(outcome.events.contains { $0.effectKind == .cleanseApplied && $0.keyword == .poison })
    }

    @Test func cleanseAllRemovesAllDebuffs() {
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
        #expect(outcome.didApply)
        // Debuffs gone, shield still present
        #expect(!(battle.activeEffects(of: battle.hero)).contains(where: \.effect.isRemovableDebuff))
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect.isTickable && !$0.effect.isRemovableDebuff })
    }

    @Test func cleanseIsInstantAndLeavesNoActiveEffect() {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)],
            for: battle.hero,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(.poison), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        #expect(outcome.didApply)
        #expect(!(battle.activeEffects(of: battle.hero)).contains { if case .cleanse = $0.effect { return true }; return false })
        #expect(!(battle.activeEffects(of: battle.hero)).contains { $0.effect.isDecayingDoT && $0.keyword == .poison })
    }

    @Test func cleanseStunRemovesActivePrevention() {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.stun, 5, 10), remainingTicks: 0)],
            for: battle.hero,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(.stun), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        #expect(outcome.didApply)
        #expect(!(battle.activeEffects(of: battle.hero)).contains(where: \.effect.isControlMeter))
    }

    @Test func cleanseRandomRemovesOneDebuff() {
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
        #expect(outcome.didApply)
        // Exactly one debuff removed
        let remainingDebuffs = battle.activeEffects(of: battle.hero).filter(\.effect.isRemovableDebuff)
        #expect(remainingDebuffs.count == 1)
    }

    // MARK: - Purge

    @Test func purgeSpecificKeywordRemovesMatchingBuffs() {
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
        #expect(outcome.didApply)
        #expect(!(battle.activeEffects(of: battle.enemy)).contains { if case .shield = $0.effect { return true }; return false })
        #expect(battle.activeEffects(of: battle.enemy).contains { if case .mitigation = $0.effect { return true }; return false })
        #expect(outcome.events.contains { $0.effectKind == .purgeApplied && $0.keyword == .block })
    }

    @Test func purgeAllRemovesBuffsButLeavesDebuffs() {
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
        #expect(outcome.didApply)
        #expect(!(battle.activeEffects(of: battle.enemy)).contains(where: \.effect.isRemovableBuff))
        #expect(battle.activeEffects(of: battle.enemy).contains(where: \.effect.isRemovableDebuff))
        #expect(outcome.events.contains { $0.effectKind == .purgeApplied && $0.keyword == .purge })
    }

    @Test func purgeRandomRemovesOneBuff() {
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
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.enemy).filter(\.effect.isRemovableBuff).count == 1)
        #expect(outcome.events.contains { $0.effectKind == .purgeApplied })
    }

    // MARK: - Debuff

    @Test func halveMitigationHandlerHalvesArmorAndEmitsEvent() {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .mitigation(.armor, 0.40, 6), remainingTicks: 6)],
            for: battle.enemy,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.halveMitigation(.armor), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.enemy).contains { ae in
            if case .mitigation(.armor, 0.20, _) = ae.effect { return true }
            return false
        })
        #expect(outcome.events.contains { $0.effectKind == .mitigationHalved && $0.keyword == .armor })
    }

    @Test func halveMitigationHandlerReportsNoApplyWhenArmorMissing() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            .halveMitigation(.armor),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle
        )
        #expect(!(outcome.didApply))
        #expect(outcome.events.isEmpty)
    }

    @Test func controlMeterHandlerAppliesThroughPipeline() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.controlMeter(.stun, 1, 10), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        #expect(outcome.didApply)
        #expect(battle.activeEffects(of: battle.enemy).contains(where: \.effect.isControlMeter))
    }

    @Test func deathsDoorHandlerApplyIsNoOp() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            .deathsDoor,
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        #expect(!(outcome.didApply))
        #expect(outcome.events.isEmpty)
    }
}
