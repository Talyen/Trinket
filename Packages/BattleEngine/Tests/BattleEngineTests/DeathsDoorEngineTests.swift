import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class DeathsDoorEngineTests: XCTestCase {
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
            build: BattleCombatBuild(hero: hero, pet: pet, heroModifiers: .zero, petModifiers: .zero)
        )
    }

    func testTriggerOnFirstLethalHit() {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        let (_, events) = context.applyTestDamage(
            5,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        XCTAssertEqual(context.roster.health(for: hero), 1)
        XCTAssertTrue(context.roster.hasConsumedDeathsDoor(for: hero))
        XCTAssertTrue(context.roster.isDeathsDoorActive(for: hero))
        XCTAssertEqual(
            context.roster.activeEffects(for: hero).first?.remainingTicks,
            BattleTiming.deathsDoorDurationTicks
        )
        XCTAssertTrue(events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
    }

    func testEnemyNeverTriggers() {
        var context = makeContext(enemyHP: 5)
        let enemy = context.roster.enemy.combatant
        _ = context.applyTestDamage(
            5,
            to: enemy,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        XCTAssertEqual(context.roster.health(for: enemy), 0)
        XCTAssertFalse(context.roster.isDeathsDoorActive(for: enemy))
    }

    func testProtectionClampsToOneWhileActive() {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        _ = context.applyTestDamage(20, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        XCTAssertEqual(context.roster.health(for: hero), 1)
        XCTAssertTrue(context.roster.isDeathsDoorActive(for: hero))
    }

    func testSecondLethalAfterExpiryKills() {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        var effects = context.roster.activeEffects(for: hero)
        for _ in 0 ..< BattleTiming.deathsDoorDurationTicks {
            let result = EffectTickEngine.tickEffects(effects, target: hero, context: &context)
            effects = result.updated
        }
        context.roster.setActiveEffects(effects, for: hero)

        XCTAssertFalse(context.roster.isDeathsDoorActive(for: hero))
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        XCTAssertEqual(context.roster.health(for: hero), 0)
        XCTAssertFalse(context.roster.hero.isAlive)
    }

    func testHeroAndPetProcIndependently() {
        var context = makeContext(heroHP: 3, petHP: 3)
        let hero = context.roster.hero.combatant
        let pet = context.roster.pet.combatant

        _ = context.applyTestDamage(3, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        _ = context.applyTestDamage(3, to: pet, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        XCTAssertTrue(context.roster.hasConsumedDeathsDoor(for: hero))
        XCTAssertTrue(context.roster.hasConsumedDeathsDoor(for: pet))
        XCTAssertTrue(context.roster.isDeathsDoorActive(for: hero))
        XCTAssertTrue(context.roster.isDeathsDoorActive(for: pet))
    }

    func testEffectInsertedAtFrontOfActiveEffects() {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0)],
            for: hero
        )

        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        let effects = context.roster.activeEffects(for: hero)
        XCTAssertEqual(effects.count, 2)
        XCTAssertEqual(effects.first?.effect.kind, .deathsDoor)
    }

    func testDoTTickTriggersDeathsDoor() {
        var context = makeContext(heroHP: 3)
        let hero = context.roster.hero.combatant
        let outcome = context.resolveDoTTick(
            basePotency: 3,
            keyword: .burn,
            target: hero,
            sourceActorID: "enemy"
        )

        XCTAssertGreaterThan(outcome.healthLost, 0)
        XCTAssertEqual(context.roster.health(for: hero), 1)
        XCTAssertTrue(outcome.events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
    }

    func testOverkillShowsActualHPLost() {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        let (lost, _) = context.applyTestDamage(
            40,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        XCTAssertEqual(lost, 5)
        XCTAssertEqual(context.roster.health(for: hero), 1)
    }
}
