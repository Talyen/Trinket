import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct EffectTurnEngineTests {
    @Test func `lethal enemy burn ends turn before party damage`() {
        let burn = ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0)
        var battle = makeContext(heroHP: 1, enemyHP: 1, enemyEffects: [burn])
        battle.roster.companion.currentHealth = 1
        for participant in [BattleParticipant.hero, .companion] {
            let combatant = battle.roster[participant].combatant
            battle.roster.mutateRuntime(for: combatant) { $0.hasConsumedDeathsDoor = true }
            battle.roster.setActiveEffects([burn], for: combatant)
        }

        _ = EffectTurnEngine.advanceAll(context: &battle)

        #expect(battle.roster.enemy.currentHealth == 0)
        #expect(battle.roster.hero.currentHealth == 1)
        #expect(battle.roster.companion.currentHealth == 1)
        #expect(BattleSimulationOutcome.resolve(
            isPartyDefeated: battle.isPartyDefeated,
            isEnemyDefeated: battle.isEnemyDefeated,
        ) == .victory)
    }

    private func makeContext(
        heroHP: Int = 50,
        enemyHP: Int = 50,
        enemyEffects: [ActiveEffect] = [],
    ) -> BattleState {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 50)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: enemyEffects,
        )
        battle.roster.hero.currentHealth = heroHP
        battle.roster.enemy.currentHealth = enemyHP
        return battle
    }

    @Test func `do T tick preserves shield depletion through tick all`() throws {
        let shield = ActiveEffect(
            id: 1,
            effect: .shield(.block, 5),
            remainingTurns: 5,
            sourceActorID: "caster",
        )
        let burn = ActiveEffect(id: 2, effect: .burn(4), remainingTurns: 0)
        var context = makeContext(enemyHP: 50, enemyEffects: [shield, burn])
        let enemy = context.roster.enemy.combatant

        _ = EffectTurnEngine.advanceEffects(
            context.roster.activeEffects(for: enemy),
            target: enemy,
            context: &context,
        )

        let shields = context.roster.activeEffects(for: enemy).compactMap { activeEffect -> Int? in
            guard case let .shield(_, buffer) = activeEffect.effect else { return nil }
            return buffer
        }
        try #expect(shields == [3], "Burn tick should erode the shield buffer before HP damage")
        try #expect(context.roster.health(for: enemy) == 50)
    }

    @Test func `do T tick preserves deaths door through tick all`() throws {
        let burn = ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 0)
        var context = makeContext(heroHP: 1, enemyEffects: [])
        let hero = context.roster.hero.combatant
        context.roster.setActiveEffects([burn], for: hero)

        _ = EffectTurnEngine.advanceEffects(
            context.roster.activeEffects(for: hero),
            target: hero,
            context: &context,
        )

        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(
            context.roster.activeEffects(for: hero).contains { $0.effect.kind == .deathsDoor },
            "Death's Door inserted during DoT damage should survive effect-pass write-back",
        )
    }

    @Test func `guardian archive cleanse prevents later dots from ticking`() throws {
        let owl = try BattleTestFixtures.catalogBuild(combatantID: "library_owl", talents: "library_owl_health_t3_1")
        var battle = BattleStateTestFactory.makeBattle(companion: owl.combatant, companionModifiers: owl.modifiers)
        battle.appliesFightPacing = false
        let hero = battle.roster.hero.combatant
        battle.roster.mutateRuntime(for: hero) { $0.currentHealth = 1 }
        battle.appendEffect(.burn(4), to: hero, sourceID: battle.roster.enemy.id, remainingTurns: 0)
        battle.appendEffect(.poison(8), to: hero, sourceID: battle.roster.enemy.id, remainingTurns: 0)

        let events = EffectTurnEngine.advanceAll(context: &battle)

        #expect(battle.roster.hero.currentHealth == 11)
        #expect(!battle.roster.activeEffects(for: hero).contains { $0.effect.isRemovableDebuff })
        #expect(!events.contains { $0.keyword == .poison && $0.amount > 0 })
    }
}
