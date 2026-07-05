import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class EffectHandlersApplyTests: XCTestCase {
    // MARK: - DoT handlers

    func testBurnHandlerAppliesBurnEffect() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        let outcome = EffectHandlersTestSupport.dispatch(.burn(3), ability: CombatantFixtures.ability(), source: battle.hero, target: enemy, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEffects(of: battle.enemy).contains { $0.effect.isDecayingDoT && $0.keyword == .burn })
    }

    func testBurnHandlerSkipsInitialDamageWhenPaired() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        let enemy = battle.enemy
        let hero = battle.hero
        let action = ActionApplyContext(pairedDirectDamage: [(.burn, 3)])
        let outcome: EffectApplyOutcome = try battle.withEngineContext { context in
            try XCTUnwrap(EffectHandlers.all[.burn]?.apply(
                .burn(3),
                ability: CombatantFixtures.ability(),
                source: hero,
                target: enemy,
                action: action,
                in: &context
            ))
        }
        XCTAssertTrue(outcome.didApply)
        // No `events` containing a status DoT damage entry.
        XCTAssertFalse(outcome.events.contains { $0.kind == .status && $0.keyword == .burn })
    }

    func testPoisonHandlerAppliesPoisonEffect() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.poison(2), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEffects(of: battle.enemy).contains { $0.effect.isDecayingDoT && $0.keyword == .poison })
    }

    func testBleedHandlerAppliesBleedEffect() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.bleed(2), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEffects(of: battle.enemy).contains(where: \.effect.isBleed))
    }

    // MARK: - Defensive buffs

    func testShieldHandlerAddsShieldAndEmitsEvent() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.shield(.block, 5, 3), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEffects(of: battle.hero).contains { ae in
            if case .shield(.block, 5, _) = ae.effect { return true }
            return false
        })
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .shieldApplied && $0.amount == 5 })
    }

    func testMitigationHandlerAddsMitigationAndEmitsEvent() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.mitigation(.armor, 0.25, 6), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEffects(of: battle.hero).contains { ae in
            if case .mitigation(.armor, 0.25, _) = ae.effect { return true }
            return false
        })
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .mitigationApplied && $0.amount == 25 })
    }

    func testLeechHandlerAddsLeechEffectAndEmitsEvent() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.standardLeechBuff, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEffects(of: battle.hero).contains { $0.effect.keyword == .leech && !$0.effect.isInstant })
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .leechApplied })
    }

    func testLeechHandlerReplacesExistingLeechInsteadOfStacking() {
        var battle = EffectHandlersTestSupport.makeBattle()
        _ = EffectHandlersTestSupport.dispatch(.standardLeechBuff, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        let outcome = EffectHandlersTestSupport.dispatch(.standardLeechBuff, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        let leechStacks = battle.activeEffects(of: battle.hero).filter { $0.effect.keyword == .leech }
        XCTAssertEqual(leechStacks.count, 1)
    }

    func testCleanseWithoutDebuffsDoesNotApply() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(.poison), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertFalse(outcome.didApply)
        XCTAssertTrue(outcome.events.isEmpty)
    }

    // MARK: - Restoration

    func testInstantHealHandlerHealsTarget() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let hero = battle.hero
        _ = battle.withEngineContext { $0.applyTestDamage(30, to: hero) }
        let before = battle.health(of: battle.hero)
        let outcome = EffectHandlersTestSupport.dispatch(.instantHeal(.health, 5), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertGreaterThan(battle.health(of: battle.hero), before)
        XCTAssertEqual(outcome.events.first?.amount, battle.health(of: battle.hero) - before)
    }

    func testInstantHealHandlerDoesNotApplyAtFullHealth() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let hero = battle.hero
        let outcome = EffectHandlersTestSupport.dispatch(
            .instantHeal(.health, 5),
            ability: CombatantFixtures.ability(),
            source: hero,
            target: hero,
            battle: &battle
        )
        XCTAssertFalse(outcome.didApply)
        XCTAssertTrue(outcome.events.isEmpty)
    }

    func testResourceGainHandlerAddsGold() {
        var battle = EffectHandlersTestSupport.makeBattle(initialGold: 10)
        let resourceEffect: Effect = .resourceGain(.gold, 3)
        let outcome = EffectHandlersTestSupport.dispatch(resourceEffect, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertEqual(battle.gold, 13)
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .resourceGain && $0.amount == 3 })
    }

    // MARK: - Cleanse

    func testCleanseSpecificKeywordRemovesMatchingEffects() {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)],
            for: battle.hero,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(.poison), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertFalse(battle.activeEffects(of: battle.hero).contains { $0.effect.isDecayingDoT && $0.keyword == .poison })
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .cleanseApplied && $0.keyword == .poison })
    }

    func testCleanseAllRemovesAllDebuffs() {
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
        XCTAssertTrue(outcome.didApply)
        // Debuffs gone, shield still present
        XCTAssertFalse(battle.activeEffects(of: battle.hero).contains(where: \.effect.isRemovableDebuff))
        XCTAssertTrue(battle.activeEffects(of: battle.hero).contains { $0.effect.isTickable && !$0.effect.isRemovableDebuff })
    }

    func testCleanseIsInstantAndLeavesNoActiveEffect() {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)],
            for: battle.hero,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(.poison), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertFalse(battle.activeEffects(of: battle.hero).contains { if case .cleanse = $0.effect { return true }; return false })
        XCTAssertFalse(battle.activeEffects(of: battle.hero).contains { $0.effect.isDecayingDoT && $0.keyword == .poison })
    }

    func testCleanseStunRemovesActivePrevention() {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.stun, 5, 10), remainingTicks: 0)],
            for: battle.hero,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(.stun), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertFalse(battle.activeEffects(of: battle.hero).contains(where: \.effect.isControlMeter))
    }

    func testCleanseRandomRemovesOneDebuff() {
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
        XCTAssertTrue(outcome.didApply)
        // Exactly one debuff removed
        let remainingDebuffs = battle.activeEffects(of: battle.hero).filter(\.effect.isRemovableDebuff)
        XCTAssertEqual(remainingDebuffs.count, 1)
    }

    // MARK: - Purge

    func testPurgeSpecificKeywordRemovesMatchingBuffs() {
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
        XCTAssertTrue(outcome.didApply)
        XCTAssertFalse(battle.activeEffects(of: battle.enemy).contains { if case .shield = $0.effect { return true }; return false })
        XCTAssertTrue(battle.activeEffects(of: battle.enemy).contains { if case .mitigation = $0.effect { return true }; return false })
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .purgeApplied && $0.keyword == .block })
    }

    func testPurgeAllRemovesBuffsButLeavesDebuffs() {
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
        XCTAssertTrue(outcome.didApply)
        XCTAssertFalse(battle.activeEffects(of: battle.enemy).contains(where: \.effect.isRemovableBuff))
        XCTAssertTrue(battle.activeEffects(of: battle.enemy).contains(where: \.effect.isRemovableDebuff))
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .purgeApplied && $0.keyword == .purge })
    }

    func testPurgeRandomRemovesOneBuff() {
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
        XCTAssertTrue(outcome.didApply)
        XCTAssertEqual(battle.activeEffects(of: battle.enemy).filter(\.effect.isRemovableBuff).count, 1)
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .purgeApplied })
    }

    // MARK: - Debuff

    func testHalveMitigationHandlerHalvesArmorAndEmitsEvent() {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .mitigation(.armor, 0.40, 6), remainingTicks: 6)],
            for: battle.enemy,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.halveMitigation(.armor), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEffects(of: battle.enemy).contains { ae in
            if case .mitigation(.armor, 0.20, _) = ae.effect { return true }
            return false
        })
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .mitigationHalved && $0.keyword == .armor })
    }

    func testHalveMitigationHandlerReportsNoApplyWhenArmorMissing() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            .halveMitigation(.armor),
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.enemy,
            battle: &battle
        )
        XCTAssertFalse(outcome.didApply)
        XCTAssertTrue(outcome.events.isEmpty)
    }

    func testControlMeterHandlerAppliesThroughPipeline() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(.controlMeter(.stun, 1, 10), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        XCTAssertTrue(outcome.didApply)
        XCTAssertTrue(battle.activeEffects(of: battle.enemy).contains(where: \.effect.isControlMeter))
    }

    func testDeathsDoorHandlerApplyIsNoOp() {
        var battle = EffectHandlersTestSupport.makeBattle()
        let outcome = EffectHandlersTestSupport.dispatch(
            .deathsDoor,
            ability: CombatantFixtures.ability(),
            source: battle.hero,
            target: battle.hero,
            battle: &battle
        )
        XCTAssertFalse(outcome.didApply)
        XCTAssertTrue(outcome.events.isEmpty)
    }
}
