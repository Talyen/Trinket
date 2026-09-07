import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct DeathsDoorEngineTests {
    private func makeContext(
        heroHP: Int = 10,
        companionHP: Int = 10,
        enemyHP: Int = 50,
        heroModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: enemyHP)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroModifiers: heroModifiers,
        )
        battle.roster.hero.currentHealth = heroHP
        battle.roster.companion.currentHealth = companionHP
        battle.roster.enemy.currentHealth = enemyHP
        return battle
    }

    @Test func `trigger on first lethal hit`() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        let (lost, events) = context.applyTestDamage(
            40,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false,
        )

        try #expect(lost == 5)
        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(
            context.roster.activeEffects(for: hero).first?.remainingTurns == BattleTiming.deathsDoorDurationTurns,
        )
        try #expect(events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
    }

    @Test func `enemy never triggers`() throws {
        var context = makeContext(enemyHP: 5)
        let enemy = context.roster.enemy.combatant
        _ = context.applyTestDamage(
            5,
            to: enemy,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false,
        )

        try #expect(context.roster.health(for: enemy) == 0)
        try #expect(!(context.roster.isDeathsDoorActive(for: enemy)))
    }

    @Test func `protection clamps to one while active`() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        _ = context.applyTestDamage(20, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.isDeathsDoorActive(for: hero))
    }

    @Test func `expiry round do T does not kill`() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        var effects = context.roster.activeEffects(for: hero)
        let burnID = (effects.map(\.id).max() ?? 0) + 1
        effects.append(ActiveEffect(id: burnID, effect: .burn(8), remainingTurns: 0, sourceActorID: context.enemy.id))
        context.roster.setActiveEffects(effects, for: hero)

        for _ in 0 ..< BattleTiming.deathsDoorDurationTurns {
            _ = context.endTurn()
        }

        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.hero.isAlive)
        try #expect(!(context.roster.isDeathsDoorActive(for: hero)))
        try #expect(context.roster.runtime(for: hero)?.deathsDoorExpiredAtTurn == context.turnCount)
    }

    @Test func `do T kills on the round after deaths door expires`() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        var effects = context.roster.activeEffects(for: hero)
        let burnID = (effects.map(\.id).max() ?? 0) + 1
        effects.append(ActiveEffect(id: burnID, effect: .burn(8), remainingTurns: 0, sourceActorID: context.enemy.id))
        context.roster.setActiveEffects(effects, for: hero)

        for _ in 0 ..< BattleTiming.deathsDoorDurationTurns {
            _ = context.endTurn()
        }
        _ = context.endTurn()

        try #expect(context.roster.health(for: hero) == 0)
        try #expect(!(context.roster.hero.isAlive))
    }

    @Test func `second wind does not preempt deaths door on lethal hit`() throws {
        var context = makeContext(
            heroHP: 5,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    onceBelowHealthPercentThreshold: 0.25,
                ),
                healing: HealingTriggers(
                    onceBelowHealthPercentHeal: 3,
                ),
            )),
        )
        let hero = context.roster.hero.combatant
        let (_, events) = context.applyTestDamage(
            5,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false,
        )

        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
        try #expect(!events.contains { $0.abilityName == "Second Wind" })
        try #expect(!(context.roster.runtime(for: hero)?.hasTriggeredSecondWind ?? true))
    }

    @Test func `hero and companion proc independently`() throws {
        var context = makeContext(heroHP: 3, companionHP: 3)
        let hero = context.roster.hero.combatant
        let companion = context.roster.companion.combatant

        _ = context.applyTestDamage(3, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        _ = context.applyTestDamage(3, to: companion, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(context.roster.hasConsumedDeathsDoor(for: companion))
        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(context.roster.isDeathsDoorActive(for: companion))
    }

    @Test func `effect inserted at front of active effects`() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(2), remainingTurns: 0)],
            for: hero,
        )

        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        let effects = context.roster.activeEffects(for: hero)
        try #expect(effects.count == 2)
        try #expect(effects.first?.effect.kind == .deathsDoor)
    }

    @Test func `do T tick triggers deaths door`() throws {
        var context = makeContext(heroHP: 2)
        let hero = context.roster.hero.combatant
        let outcome = context.resolveDoTTick(
            basePotency: 3,
            keyword: .burn,
            target: hero,
            sourceActorID: "enemy",
        )

        try #expect(outcome.healthLost > 0)
        try #expect(context.roster.health(for: hero) == 1)
        try #expect(outcome.events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
    }

    private func makeLegionContext(heroHealth: Int) -> BattleState {
        BattleTestFixtures.makeContext(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(),
            heroHealth: heroHealth,
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(revival: RevivalTriggers(deathsDoorExpiredHealFlat: 10)),
            ),
        )
    }

    @Test func `endless legion raises health to floor exactly`() throws {
        var context = makeLegionContext(heroHealth: 3)
        let hero = context.roster.hero.combatant

        let events = DeathsDoorEngine.afterDeathsDoorExpired(on: hero, in: &context)

        try #expect(context.roster.health(for: hero) == 10)
        try #expect(events.contains { $0.effectKind == .instantHeal && $0.amount == 7 })
    }

    @Test func `endless legion does nothing at or above floor`() throws {
        var context = makeLegionContext(heroHealth: 12)
        let hero = context.roster.hero.combatant

        let events = DeathsDoorEngine.afterDeathsDoorExpired(on: hero, in: &context)

        try #expect(events.isEmpty)
        try #expect(context.roster.health(for: hero) == 12)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `guardian archive protects either party member`(owner: BattleParticipant) throws {
        let owl = try BattleTestFixtures.catalogBuild(combatantID: "library_owl", talents: "library_owl_health_t3_1")
        var battle = BattleStateTestFactory.makeBattle(companion: owl.combatant, companionModifiers: owl.modifiers)
        battle.appliesFightPacing = false
        let target = battle.roster[owner].combatant
        battle.roster.mutateRuntime(for: target) { $0.currentHealth = 1 }
        battle.appendEffect(.poison(8), to: target, sourceID: battle.roster.enemy.id, remainingTurns: 0)

        _ = battle.applyTestDamage(1, to: target, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        #expect(battle.roster.health(for: target) == min(11, battle.roster.maxHealth(for: target)))
        #expect(!battle.roster.activeEffects(for: target).contains { $0.effect.isRemovableDebuff })
    }
}
