import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct EffectTurnEngineTests {
    private func makeContext(
        heroHP: Int = 50,
        enemyHP: Int = 50,
        enemyEffects: [ActiveEffect] = []
    ) -> BattleState {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 50)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: enemyEffects
        )
        battle.roster.hero.currentHealth = heroHP
        battle.roster.enemy.currentHealth = enemyHP
        return battle
    }

    @Test func doTTickPreservesShieldDepletionThroughTickAll() throws {
        let shield = ActiveEffect(
            id: 1,
            effect: .shield(.block, 5),
            remainingTurns: 5,
            sourceActorID: "caster"
        )
        let burn = ActiveEffect(id: 2, effect: .burn(4), remainingTurns: 0)
        var context = makeContext(enemyHP: 50, enemyEffects: [shield, burn])
        let enemy = context.roster.enemy.combatant

        let result = EffectTurnEngine.advanceEffects(
            context.roster.activeEffects(for: enemy),
            target: enemy,
            context: &context
        )
        context.roster.setActiveEffects(result.updated, for: enemy)

        let shields = context.roster.activeEffects(for: enemy).compactMap { activeEffect -> Int? in
            guard case let .shield(_, buffer) = activeEffect.effect else { return nil }
            return buffer
        }
        try #expect(shields == [3], "Burn tick should erode the shield buffer before HP damage")
        try #expect(context.roster.health(for: enemy) == 50)
    }

    @Test func doTTickPreservesDeathsDoorThroughTickAll() throws {
        let burn = ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 0)
        var context = makeContext(heroHP: 1, enemyEffects: [])
        let hero = context.roster.hero.combatant
        context.roster.setActiveEffects([burn], for: hero)

        let result = EffectTurnEngine.advanceEffects(
            context.roster.activeEffects(for: hero),
            target: hero,
            context: &context
        )
        context.roster.setActiveEffects(result.updated, for: hero)

        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(
            context.roster.activeEffects(for: hero).contains { $0.effect.kind == .deathsDoor },
            "Death's Door inserted during DoT damage should survive effect-tick write-back"
        )
    }
}
