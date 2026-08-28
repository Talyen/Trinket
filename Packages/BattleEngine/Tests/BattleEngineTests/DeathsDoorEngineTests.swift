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
        heroModifiers: CombatModifierProfile = .zero
    ) -> BattleState {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: enemyHP)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroModifiers: heroModifiers
        )
        battle.roster.hero.currentHealth = heroHP
        battle.roster.companion.currentHealth = companionHP
        battle.roster.enemy.currentHealth = enemyHP
        return battle
    }

    @Test func triggerOnFirstLethalHit() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        let (lost, events) = context.applyTestDamage(
            40,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        try #expect(lost == 5)
        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(
            context.roster.activeEffects(for: hero).first?.remainingTurns == BattleTiming.deathsDoorDurationTurns
        )
        try #expect(events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
    }

    @Test func enemyNeverTriggers() throws {
        var context = makeContext(enemyHP: 5)
        let enemy = context.roster.enemy.combatant
        _ = context.applyTestDamage(
            5,
            to: enemy,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        try #expect(context.roster.health(for: enemy) == 0)
        try #expect(!(context.roster.isDeathsDoorActive(for: enemy)))
    }

    @Test func protectionClampsToOneWhileActive() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        _ = context.applyTestDamage(20, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.isDeathsDoorActive(for: hero))
    }

    @Test func expiryRoundDoTDoesNotKill() throws {
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
        try #expect(context.roster.runtime(for: hero)?.deathsDoorExpiredAtTurn == nil)
    }

    @Test func doTKillsOnTheRoundAfterDeathsDoorExpires() throws {
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

    @Test func secondWindDoesNotPreemptDeathsDoorOnLethalHit() throws {
        var context = makeContext(
            heroHP: 5,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                control: ControlTriggers(
                    onceBelowHealthPercentThreshold: 0.25
                ),
                healing: HealingTriggers(
                    onceBelowHealthPercentHeal: 3
                )
            ))
        )
        let hero = context.roster.hero.combatant
        let (_, events) = context.applyTestDamage(
            5,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
        try #expect(!events.contains { $0.abilityName == "Second Wind" })
        try #expect(!(context.roster.runtime(for: hero)?.hasTriggeredSecondWind ?? true))
    }

    @Test func heroAndCompanionProcIndependently() throws {
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

    @Test func effectInsertedAtFrontOfActiveEffects() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(2), remainingTurns: 0)],
            for: hero
        )

        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        let effects = context.roster.activeEffects(for: hero)
        try #expect(effects.count == 2)
        try #expect(effects.first?.effect.kind == .deathsDoor)
    }

    @Test func doTTickTriggersDeathsDoor() throws {
        var context = makeContext(heroHP: 2)
        let hero = context.roster.hero.combatant
        let outcome = context.resolveDoTTick(
            basePotency: 3,
            keyword: .burn,
            target: hero,
            sourceActorID: "enemy"
        )

        try #expect(outcome.healthLost > 0)
        try #expect(context.roster.health(for: hero) == 1)
        try #expect(outcome.events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
    }

    private func makeLegionContext(heroHealth: Int) -> BattleState {
        BattleTestFixtures.makeContext(
            hero: BattleTestFixtures.passiveHero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            heroHealth: heroHealth,
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(revival: RevivalTriggers(deathsDoorExpiredHealFlat: 10))
            )
        )
    }

    @Test func endlessLegionRaisesHealthToFloorExactly() throws {
        var context = makeLegionContext(heroHealth: 3)
        let hero = context.roster.hero.combatant

        let events = DeathsDoorEngine.afterDeathsDoorExpired(on: hero, in: &context)

        try #expect(context.roster.health(for: hero) == 10)
        try #expect(events.contains { $0.effectKind == .instantHeal && $0.amount == 7 })
    }

    @Test func endlessLegionDoesNothingAtOrAboveFloor() throws {
        var context = makeLegionContext(heroHealth: 12)
        let hero = context.roster.hero.combatant

        let events = DeathsDoorEngine.afterDeathsDoorExpired(on: hero, in: &context)

        try #expect(events.isEmpty)
        try #expect(context.roster.health(for: hero) == 12)
    }
}
