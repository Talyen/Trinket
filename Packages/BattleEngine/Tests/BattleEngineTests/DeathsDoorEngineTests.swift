import Testing
import TrinketTestSupport
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

    @Test func triggerOnFirstLethalHit() throws {
        var context = makeContext(heroHP: 5)
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
        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(
            context.roster.activeEffects(for: hero).first?.remainingTicks == BattleTiming.deathsDoorDurationTicks
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

    @Test func secondLethalAfterExpiryKills() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        var effects = context.roster.activeEffects(for: hero)
        for _ in 0 ..< BattleTiming.deathsDoorDurationTicks {
            let result = EffectTickEngine.tickEffects(effects, target: hero, context: &context)
            effects = result.updated
        }
        context.roster.setActiveEffects(effects, for: hero)
        // Expiry grace only lasts through the tick that removed Death's Door.
        context.tickCount += 1
        context.roster.mutateRuntime(for: hero) { $0.deathsDoorExpiredAtTick = nil }

        try #expect(!(context.roster.isDeathsDoorActive(for: hero)))
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        try #expect(context.roster.health(for: hero) == 0)
        try #expect(!(context.roster.hero.isAlive))
    }

    @Test func lethalHitSameTickAfterExpiryStillClampsToOne() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        var effects = context.roster.activeEffects(for: hero)
        for _ in 0 ..< BattleTiming.deathsDoorDurationTicks {
            let result = EffectTickEngine.tickEffects(effects, target: hero, context: &context)
            effects = result.updated
        }
        context.roster.setActiveEffects(effects, for: hero)

        try #expect(!(context.roster.isDeathsDoorActive(for: hero)))
        try #expect(context.roster.runtime(for: hero)?.deathsDoorExpiredAtTick == context.tickCount)
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.hero.isAlive)
    }

    @Test func secondWindDoesNotPreemptDeathsDoorOnLethalHit() throws {
        var context = makeContext(heroHP: 5)
        context.heroModifiers = CombatModifierProfile(
            onceBelowHealthPercentThreshold: 0.25,
            onceBelowHealthPercentHeal: 3
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

    @Test func heroAndPetProcIndependently() throws {
        var context = makeContext(heroHP: 3, petHP: 3)
        let hero = context.roster.hero.combatant
        let pet = context.roster.pet.combatant

        _ = context.applyTestDamage(3, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        _ = context.applyTestDamage(3, to: pet, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(context.roster.hasConsumedDeathsDoor(for: pet))
        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(context.roster.isDeathsDoorActive(for: pet))
    }

    @Test func effectInsertedAtFrontOfActiveEffects() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0)],
            for: hero
        )

        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        let effects = context.roster.activeEffects(for: hero)
        try #expect(effects.count == 2)
        try #expect(effects.first?.effect.kind == .deathsDoor)
    }

    @Test func doTTickTriggersDeathsDoor() throws {
        var context = makeContext(heroHP: 3)
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

    @Test func overkillShowsActualHPLost() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        let (lost, _) = context.applyTestDamage(
            40,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        try #expect(lost == 5)
        try #expect(context.roster.health(for: hero) == 1)
    }
}
