import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct EffectHandlersApplyStatusTests {
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
                ActiveEffect(id: 3, effect: .shield(.block, 5), remainingTicks: 6)
            ],
            for: battle.hero,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.cleanse(nil), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.hero, battle: &battle)
        try #expect(outcome.didApply)
        // Debuffs gone, shield still present
        try #expect(!(battle.activeEffects(of: battle.hero)).contains(where: \.effect.isRemovableDebuff))
        try #expect(battle.activeEffects(of: battle.hero).contains { ae in
            if case .shield(.block, 5) = ae.effect {
                return true
            }
            return false
        })
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
        try #expect(!(battle.activeEffects(of: battle.hero)).contains {
            if case .cleanse = $0.effect {
                return true
            }; return false
        })
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
                ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 6),
                ActiveEffect(id: 2, effect: .mitigation(.armor, 2), remainingTicks: 6)
            ],
            for: battle.enemy,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.purge(.block), ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(!(battle.activeEffects(of: battle.enemy)).contains {
            if case .shield = $0.effect {
                return true
            }; return false
        })
        try #expect(battle.activeEffects(of: battle.enemy).contains {
            if case .mitigation = $0.effect {
                return true
            }; return false
        })
        try #expect(outcome.events.contains { $0.effectKind == .purgeApplied && $0.keyword == .block })
    }

    @Test func purgeAllRemovesBuffsButLeavesDebuffs() throws {
        var battle = EffectHandlersTestSupport.makeBattle()
        BattleStateTestFactory.seedActiveEffects(
            [
                ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 6),
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
                ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 6),
                ActiveEffect(id: 2, effect: .mitigation(.armor, 2), remainingTicks: 6)
            ],
            for: battle.enemy,
            on: &battle
        )
        let outcome = EffectHandlersTestSupport.dispatch(.purgeRandom, ability: CombatantFixtures.ability(), source: battle.hero, target: battle.enemy, battle: &battle)
        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.enemy).filter(\.effect.isRemovableBuff).count == 1)
        try #expect(outcome.events.contains { $0.effectKind == .purgeApplied })
    }
}
