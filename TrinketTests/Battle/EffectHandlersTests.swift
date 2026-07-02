import XCTest
@testable import Trinket

/// Per-handler tests. Each handler gets a focused test that constructs a
/// minimal `BattleState` and applies the corresponding effect through the
/// dispatch table (`EffectHandlers.all`). The tests pin the per-effect
/// behavior so refactors in `BattleState` can't silently change outcomes.
final class EffectHandlersTests: XCTestCase {
    // MARK: - Fixtures

    private func makeBattle(
        hero: Combatant? = nil,
        pet: Combatant? = nil,
        enemy: Combatant? = nil,
        initialGold: Int = 0
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: hero ?? CombatantFixtures.combatant(id: "hero", role: .hero),
            pet: pet ?? CombatantFixtures.combatant(id: "pet", role: .pet),
            enemy: enemy ?? CombatantFixtures.combatant(id: "enemy", role: .enemy),
            initialGold: initialGold
        )
    }

    private func dispatch(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        battle: inout BattleState
    ) -> EffectApplyOutcome {
        var hits: [(Keyword, Int)] = []
        var context = battle.makeMutationContext()
        let outcome = EffectHandlers.all[effect.kind]!.apply(
            effect,
            ability: ability,
            source: source,
            target: target,
            in: &context
        )
        battle.applyMutationContext(context)
        return outcome
    }

    private func dispatchTick(
        _ active: ActiveEffect,
        target: Combatant,
        battle: inout BattleState
    ) -> EffectTickOutcome {
        var context = battle.makeMutationContext()
        let outcome = EffectHandlers.all[active.effect.kind]!.tick(active, on: target, in: &context)
        battle.applyMutationContext(context)
        return outcome
    }

    // MARK: - Registry

    func testRegistryContainsEveryEffectKind() {
        for kind in [
            EffectKind.burn, .poison, .bleed, .prevention, .preventionBuildup,
            .shield, .mitigation, .instantHeal, .leech, .resourceGain,
            .cleanse, .cleanseRandom, .dealDamage, .halveMitigation, .dodge
        ] {
            XCTAssertNotNil(EffectHandlers.all[kind], "Missing handler for \(kind)")
            XCTAssertEqual(EffectHandlers.all[kind]?.kind, kind)
        }
    }

    // MARK: - DoT handlers

    func testBurnHandlerAppliesBurnEffect() {
        var battle = makeBattle()
        let enemy = battle.enemy
        let outcome = dispatch(.burn(3), ability: CombatantFixtures.ability(), source: battle.hero, target: enemy, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEnemyEffects.contains { $0.effect.isDecayingDoT && $0.keyword == .burn })
    }

    func testBurnHandlerSkipsInitialDamageWhenPaired() throws {
        var battle = makeBattle()
        let enemy = battle.enemy
        var hits: [(Keyword, Int)] = []
        var context = battle.makeMutationContext()
        context.pairedDirectDamage = [(.burn, 3)]
        let outcome = try XCTUnwrap(EffectHandlers.all[.burn]?.apply(
            .burn(3),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: enemy,
            in: &context
        ))
        battle.applyMutationContext(context)
        XCTAssertTrue(outcome.didApply)
        // No `events` containing a status DoT damage entry.
        XCTAssertFalse(outcome.events.contains { $0.kind == .status && $0.keyword == .burn })
    }

    func testPoisonHandlerAppliesPoisonEffect() {
        var battle = makeBattle()
        let outcome = dispatch(.poison(2), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEnemyEffects.contains { $0.effect.isDecayingDoT && $0.keyword == .poison })
    }

    func testBleedHandlerAppliesBleedEffect() {
        var battle = makeBattle()
        let outcome = dispatch(.bleed(2), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEnemyEffects.contains(where: \.effect.isBleed))
    }

    // MARK: - Defensive buffs

    func testPreventionHandlerAddsActiveEffect() {
        var battle = makeBattle()
        let outcome = dispatch(.prevention(.stun, 1), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEnemyEffects.contains { ae in
            if case .prevention(.stun, _) = ae.effect { return true }
            return false
        })
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .preventionApplied })
    }

    func testPreventionHandlerSkipsOnDeadTarget() {
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 1)
        var battle = makeBattle(enemy: enemy)
        _ = battle.applyDamage(99, to: battle.enemy)
        let outcome = dispatch(.prevention(.stun, 1), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        XCTAssertFalse(outcome.didApply)
        XCTAssertTrue(outcome.events.isEmpty)
    }

    func testShieldHandlerAddsShieldAndEmitsEvent() {
        var battle = makeBattle()
        let outcome = dispatch(.shield(.block, 5, 3), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeHeroEffects.contains { ae in
            if case .shield(.block, 5, _) = ae.effect { return true }
            return false
        })
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .shieldApplied && $0.amount == 5 })
    }

    func testMitigationHandlerAddsMitigationAndEmitsEvent() {
        var battle = makeBattle()
        let outcome = dispatch(.mitigation(.armor, 0.25, 6), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeHeroEffects.contains { ae in
            if case .mitigation(.armor, 0.25, _) = ae.effect { return true }
            return false
        })
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .mitigationApplied && $0.amount == 25 })
    }

    func testDodgeHandlerAddsDodgeEffect() {
        var battle = makeBattle()
        let outcome = dispatch(.dodge(.dodge, 3), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeHeroEffects.contains(where: \.effect.isDodge))
    }

    func testLeechHandlerAddsLeechEffect() {
        var battle = makeBattle()
        let outcome = dispatch(.standardLeechBuff, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeHeroEffects.contains { $0.effect.keyword == .leech && !$0.effect.isInstant })
    }

    // MARK: - Restoration

    func testInstantHealHandlerHealsTarget() {
        var battle = makeBattle()
        _ = battle.applyDamage(30, to: battle.hero)
        let before = battle.heroHealth
        let outcome = dispatch(.instantHeal(.health, 5), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertGreaterThan(battle.heroHealth, before)
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .instantHeal && $0.amount == 5 })
    }

    func testResourceGainHandlerAddsGold() {
        var battle = makeBattle(initialGold: 10)
        let resourceEffect: Effect = .resourceGain(.gold, 3)
        let outcome = dispatch(resourceEffect, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertEqual(battle.gold, 13)
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .resourceGain && $0.amount == 3 })
    }

    // MARK: - Cleanse

    func testCleanseSpecificKeywordRemovesMatchingEffects() {
        var battle = makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)],
            for: battle.hero,
            on: &battle
        )
        let outcome = dispatch(.cleanse(.poison, 0), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertFalse(battle.activeHeroEffects.contains { $0.effect.isDecayingDoT && $0.keyword == .poison })
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .cleanseApplied && $0.keyword == .poison })
    }

    func testCleanseAllRemovesAllDebuffs() {
        var battle = makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0),
                ActiveEffect(id: 3, effect: .shield(.block, 5, 6), remainingTicks: 6)
            ],
            for: battle.hero,
            on: &battle
        )
        let outcome = dispatch(.cleanse(nil, 0), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        // Debuffs gone, shield still present
        XCTAssertFalse(battle.activeHeroEffects.contains(where: \.effect.isRemovableDebuff))
        XCTAssertTrue(battle.activeHeroEffects.contains { $0.effect.isTickable && !$0.effect.isRemovableDebuff })
    }

    func testCleanseWithDurationAddsActiveEffect() {
        var battle = makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)],
            for: battle.hero,
            on: &battle
        )
        let outcome = dispatch(.cleanse(.poison, 3), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeHeroEffects.contains { ae in
            if case .cleanse(.poison, 3) = ae.effect { return true }
            return false
        })
    }

    func testCleanseRandomRemovesOneDebuff() {
        var battle = makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0)
            ],
            for: battle.hero,
            on: &battle
        )
        let outcome = dispatch(.cleanseRandom, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        // Exactly one debuff removed
        let remainingDebuffs = battle.activeHeroEffects.filter(\.effect.isRemovableDebuff)
        XCTAssertEqual(remainingDebuffs.count, 1)
    }

    // MARK: - Damage

    func testDealDamageHandlerDealsTypedDamage() {
        var battle = makeBattle()
        let before = battle.enemyHealth
        let damageEffect: Effect = .dealDamage(.burn, 4)
        let outcome = dispatch(damageEffect, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertLessThan(battle.enemyHealth, before)
        XCTAssertTrue(outcome.events.contains { $0.kind == .ability && $0.amount == 4 && $0.keyword == .burn })
    }

    func testDealDamageHandlerAppendsToPairedDamageHits() throws {
        var battle = makeBattle()
        var context = battle.makeMutationContext()
        _ = try XCTUnwrap(EffectHandlers.all[.dealDamage]?.apply(
            .dealDamage(.bleed, 3),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            in: &context
        ))
        XCTAssertTrue(context.pairedDirectDamage.contains(where: { $0 == (.bleed, 3) }))
        battle.applyMutationContext(context)
    }

    // MARK: - Debuff

    func testHalveMitigationHandlerHalvesArmor() {
        var battle = makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .mitigation(.armor, 0.40, 6), remainingTicks: 6)],
            for: battle.enemy,
            on: &battle
        )
        let outcome = dispatch(.halveMitigation(.armor), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEnemyEffects.contains { ae in
            if case .mitigation(.armor, 0.20, _) = ae.effect { return true }
            return false
        })
    }

    func testPreventionBuildupHandlerIsNoOp() {
        var battle = makeBattle()
        let effectsBefore = battle.activeEnemyEffects
        let outcome = dispatch(.preventionBuildup(.stun, 1, 10), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        XCTAssertFalse(outcome.didApply)
        XCTAssertTrue(outcome.events.isEmpty)
        XCTAssertEqual(battle.activeEnemyEffects, effectsBefore)
    }

    // MARK: - Tick

    func testBleedTickDealsDamageAndDecrementsRemainingTicks() {
        var battle = makeBattle()
        let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 3, sourceActorID: "hero")
        var outcome = dispatchTick(bleed, target: battle.enemy, battle: &battle)
        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.updatedStack?.remainingTicks, 2)
        XCTAssertFalse(outcome.removeAfter)
    }

    func testBleedTickWithZeroRemainingTicksIsNoOp() {
        var battle = makeBattle()
        let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 0, sourceActorID: "hero")
        let outcome = dispatchTick(bleed, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.events.isEmpty)
        XCTAssertNil(outcome.updatedStack)
    }

    func testBleedTickAtOneRemainingTickMarksForRemoval() {
        var battle = makeBattle()
        let bleed = ActiveEffect(id: 1, effect: .bleed(3), remainingTicks: 1, sourceActorID: "hero")
        let outcome = dispatchTick(bleed, target: battle.enemy, battle: &battle)
        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.updatedStack?.remainingTicks, 0)
        XCTAssertTrue(outcome.removeAfter)
    }

    func testBurnTickHalvesPotency() {
        var battle = makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0, sourceActorID: "hero")
        let outcome = dispatchTick(burn, target: battle.enemy, battle: &battle)
        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.updatedStack?.effect.potency, 2)
        XCTAssertFalse(outcome.removeAfter)
    }

    func testBurnTickAtPotencyTwoGoesToOne() {
        var battle = makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0, sourceActorID: "hero")
        let outcome = dispatchTick(burn, target: battle.enemy, battle: &battle)
        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.updatedStack?.effect.potency, 1)
        XCTAssertFalse(outcome.removeAfter)
    }

    func testBurnTickAtPotencyOneIsMarkedForRemoval() {
        var battle = makeBattle()
        let burn = ActiveEffect(id: 1, effect: .burn(1), remainingTicks: 0, sourceActorID: "hero")
        let outcome = dispatchTick(burn, target: battle.enemy, battle: &battle)
        XCTAssertEqual(outcome.events.count, 0)
        XCTAssertEqual(outcome.updatedStack?.effect.potency, 0)
        XCTAssertTrue(outcome.removeAfter)
    }

    func testPoisonTickDecaysPotency() {
        var battle = makeBattle()
        let poison = ActiveEffect(id: 1, effect: .poison(8), remainingTicks: 0, sourceActorID: "hero")
        let outcome = dispatchTick(poison, target: battle.enemy, battle: &battle)
        XCTAssertEqual(outcome.events.count, 1)
        // 8 - max(1, 8 * 25 / 100) = 8 - 2 = 6
        XCTAssertEqual(outcome.updatedStack?.effect.potency, 6)
        XCTAssertFalse(outcome.removeAfter)
    }

    func testPoisonTickAtPotencyTwoIsMarkedForRemoval() {
        var battle = makeBattle()
        let poison = ActiveEffect(id: 1, effect: .poison(2), remainingTicks: 0, sourceActorID: "hero")
        let outcome = dispatchTick(poison, target: battle.enemy, battle: &battle)
        // 2 - max(1, 0) = 1
        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.updatedStack?.effect.potency, 1)
        XCTAssertFalse(outcome.removeAfter)
    }

    func testDefaultTickDecrementsDurationForTickableBuffs() {
        var battle = makeBattle()
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 5, 6), remainingTicks: 6, sourceActorID: "hero")
        let outcome = dispatchTick(shield, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.events.isEmpty)
        XCTAssertEqual(outcome.updatedStack?.remainingTicks, 5)
        XCTAssertFalse(outcome.removeAfter)
    }
}
