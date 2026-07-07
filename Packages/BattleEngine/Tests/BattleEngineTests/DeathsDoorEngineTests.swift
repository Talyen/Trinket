import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct DeathsDoorEngineTests {
    private func makeContext(
        heroHP: Int = 10,
        petHP: Int = 10,
        enemyHP: Int = 50
    ) -> BattleEngineContext {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: enemyHP)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: hero, initialHealth: heroHP),
            pet: CombatantRuntime(combatant: pet, initialHealth: petHP),
            enemy: CombatantRuntime(combatant: enemy)
        )
        return BattleEngineContext(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: 1,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: .zero
        )
    }

    @Test func triggerOnFirstLethalHit() {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        let (_, events) = context.applyTestDamage(
            5,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        #expect(context.roster.health(for: hero) == 1)
        #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        #expect(context.roster.isDeathsDoorActive(for: hero))
        #expect(
            context.roster.activeEffects(for: hero).first?.remainingTicks == BattleTiming.deathsDoorDurationTicks
        )
        #expect(events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
    }

    @Test func enemyNeverTriggers() {
        var context = makeContext(enemyHP: 5)
        let enemy = context.roster.enemy.combatant
        _ = context.applyTestDamage(
            5,
            to: enemy,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        #expect(context.roster.health(for: enemy) == 0)
        #expect(!(context.roster.isDeathsDoorActive(for: enemy)))
    }

    @Test func protectionClampsToOneWhileActive() {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        _ = context.applyTestDamage(20, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        #expect(context.roster.health(for: hero) == 1)
        #expect(context.roster.isDeathsDoorActive(for: hero))
    }

    @Test func secondLethalAfterExpiryKills() {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        var effects = context.roster.activeEffects(for: hero)
        for _ in 0 ..< BattleTiming.deathsDoorDurationTicks {
            let result = EffectTickEngine.tickEffects(effects, target: hero, context: &context)
            effects = result.updated
        }
        context.roster.setActiveEffects(effects, for: hero)

        #expect(!(context.roster.isDeathsDoorActive(for: hero)))
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        #expect(context.roster.health(for: hero) == 0)
        #expect(!(context.roster.hero.isAlive))
    }

    @Test func heroAndPetProcIndependently() {
        var context = makeContext(heroHP: 3, petHP: 3)
        let hero = context.roster.hero.combatant
        let pet = context.roster.pet.combatant

        _ = context.applyTestDamage(3, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        _ = context.applyTestDamage(3, to: pet, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        #expect(context.roster.hasConsumedDeathsDoor(for: pet))
        #expect(context.roster.isDeathsDoorActive(for: hero))
        #expect(context.roster.isDeathsDoorActive(for: pet))
    }

    @Test func effectInsertedAtFrontOfActiveEffects() {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0)],
            for: hero
        )

        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        let effects = context.roster.activeEffects(for: hero)
        #expect(effects.count == 2)
        #expect(effects.first?.effect.kind == .deathsDoor)
    }

    @Test func doTTickTriggersDeathsDoor() {
        var context = makeContext(heroHP: 3)
        let hero = context.roster.hero.combatant
        let outcome = context.resolveDoTTick(
            basePotency: 3,
            keyword: .burn,
            target: hero,
            sourceActorID: "enemy"
        )

        #expect(outcome.healthLost > 0)
        #expect(context.roster.health(for: hero) == 1)
        #expect(outcome.events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
    }

    @Test func overkillShowsActualHPLost() {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        let (lost, _) = context.applyTestDamage(
            40,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        #expect(lost == 5)
        #expect(context.roster.health(for: hero) == 1)
    }
}
