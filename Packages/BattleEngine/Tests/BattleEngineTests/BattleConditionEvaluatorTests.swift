import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct BattleConditionEvaluatorTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `most debuffed ally skips defeated member`(defeated: BattleParticipant) throws {
        var battle = BattleStateTestFactory.makeBattle()
        let fallen = battle.roster[defeated].combatant
        let survivor = defeated == .hero ? battle.companion : battle.hero
        battle.roster.mutateRuntime(for: fallen) { $0.currentHealth = 0 }
        BattleStateTestFactory.seedActiveEffects([
            ActiveEffect(id: 1, effect: .poison(4), remainingTurns: 0),
            ActiveEffect(id: 2, effect: .burn(4), remainingTurns: 0),
        ], for: fallen, on: &battle)
        BattleStateTestFactory.seedActiveEffects([
            ActiveEffect(id: 3, effect: .poison(2), remainingTurns: 0),
        ], for: survivor, on: &battle)

        _ = EffectHandlersTestSupport.dispatch(
            .panacea(baseHeal: 3, healPerDebuff: 2),
            source: survivor, target: survivor, battle: &battle,
        )

        try #expect(!battle.activeEffects(of: survivor).contains(where: \.effect.isRemovableDebuff))
        #expect(battle.activeEffects(of: fallen).count == 2)
    }

    @Test func `lowest health ally prefers living combatant when hero is defeated`() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            seed: 0,
        )
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 0 }
        context.roster.mutateRuntime(for: companion) { $0.currentHealth = 8 }

        let target = BattleConditionEvaluator.lowestHealthAlly(
            hero: hero,
            companion: companion,
            context: context,
        )

        try #expect(target.id == companion.id)
    }

    @Test func `enemy bleeding requires active bleed stack`() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        let expiredBleed = ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 0, sourceActorID: hero.id)
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            enemyEffects: [expiredBleed],
            seed: 0,
        )

        try #expect(!BattleConditionEvaluator.isMet(
            .enemyBleeding,
            actor: hero,
            in: context,
        ))
    }
}
