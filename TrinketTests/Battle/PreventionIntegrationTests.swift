import XCTest
@testable import Trinket

/// Integration tests for stun, freeze, and prevention build-up through full battle ticks.
final class PreventionIntegrationTests: XCTestCase {
    // MARK: - Direct prevention

    func testStunSkipsTargetAction() {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero, actionIntervalTicks: 2)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .prevention(.stun, 1), remainingTicks: 1)
            ]
        )

        let events = BattleTestFixtures.advanceTicks(6, on: &battle)

        XCTAssertEqual(battle.heroHealth, hero.maxHealth)
        XCTAssertTrue(events.contains(effectKind: .preventionSkipped, keyword: .stun))
    }

    func testFreezePreventsAction() {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero, actionIntervalTicks: 2)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .prevention(.freeze, 1), remainingTicks: 1)
            ]
        )

        let events = BattleTestFixtures.advanceTicks(6, on: &battle)

        XCTAssertEqual(battle.heroHealth, hero.maxHealth)
        XCTAssertTrue(events.contains(effectKind: .preventionSkipped, keyword: .freeze))
    }

    func testShieldBashStunsLowHpEnemyNextAction() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.shieldBash]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 5, actionIntervalTicks: 2)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        BattleTestFixtures.advanceTicks(2, on: &battle)
        let events = BattleTestFixtures.advanceTicks(4, on: &battle)

        XCTAssertTrue(events.contains(effectKind: .preventionSkipped, keyword: .stun))
        XCTAssertEqual(battle.heroHealth, hero.maxHealth)
    }

    func testShieldBashGrantsBlockAlongsideStunDamage() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.shieldBash]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash])
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        BattleTestFixtures.advanceTicks(2, on: &battle)

        XCTAssertTrue(battle.hasHeroEffect { effect in
            if case let .shield(.block, buffer, _) = effect, buffer > 0 { return true }
            return false
        })
    }

    func testPreventionDoesNotExpireFromTickDecay() {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero, actionIntervalTicks: 2)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .prevention(.stun, 1), remainingTicks: 1)
            ]
        )

        BattleTestFixtures.advanceTicks(5, on: &battle)
        XCTAssertFalse(battle.activeEnemyEffects.isEmpty)

        let step = battle.advanceOneStep()
        if case let .acted(_, events) = step {
            XCTAssertTrue(events.contains { $0.effectKind == .preventionSkipped })
        } else {
            XCTFail("Expected stunned enemy to act on tick 6")
        }
    }

    func testStunClaimsItsOwnStep() {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero, actionIntervalTicks: 2)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .prevention(.stun, 1), remainingTicks: 1)
            ]
        )

        BattleTestFixtures.advanceTicks(5, on: &battle)

        let step = battle.advanceOneStep()
        if case let .acted(actor, events) = step {
            XCTAssertEqual(actor.id, enemy.id)
            XCTAssertTrue(events.contains { $0.effectKind == .preventionSkipped })
            XCTAssertFalse(events.contains { $0.kind == .ability })
        } else {
            XCTFail("Expected stunned enemy to claim its step")
        }
    }

    // MARK: - Build-up

    func testStunBuildupAccumulatesFromStunDamage() {
        let hero = BattleTestFixtures.stunAbilityHero(damage: 1)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.silentEnemy(maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        BattleTestFixtures.advanceTicks(2, on: &battle)

        let buildup = battle.firstEnemyEffect { $0.isPreventionBuildup }
        XCTAssertNotNil(buildup)
        if let values = buildup?.effect.preventionBuildupValues {
            XCTAssertGreaterThan(values.1, 0)
            XCTAssertEqual(values.2, 20)
        }
    }

    func testStunBuildupTriggersStunAtThreshold() {
        let hero = BattleTestFixtures.stunAbilityHero(damage: 1)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 5, actionIntervalTicks: 2)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        let events = BattleTestFixtures.advanceTicks(6, on: &battle)

        XCTAssertTrue(events.contains(effectKind: .preventionTriggered, keyword: .stun))
        XCTAssertTrue(events.contains(effectKind: .preventionSkipped, keyword: .stun))
    }

    func testStunBuildupOverflowIsWasted() {
        let hero = BattleTestFixtures.stunAbilityHero(damage: 50)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.silentEnemy(maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        BattleTestFixtures.advanceTicks(1, on: &battle)

        XCTAssertNil(battle.firstEnemyEffect { $0.isPreventionBuildup }, "Build-up should be consumed on trigger")
        XCTAssertTrue(battle.hasEnemyEffect { $0.isPrevention })
    }

    func testStunBuildupNotTrackedWhileStunned() {
        let hero = BattleTestFixtures.stunAbilityHero(damage: 3)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.silentEnemy(maxHealth: 10)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        BattleTestFixtures.advanceTicks(2, on: &battle)

        let stunnedCount = battle.activeEnemyEffects.filter { ae in
            if case .prevention(.stun, _) = ae.effect { return true }
            return false
        }.count
        let buildupCount = battle.activeEnemyEffects.filter(\.effect.isPreventionBuildup).count
        XCTAssertEqual(stunnedCount, 1, "Enemy should be stunned")
        XCTAssertEqual(buildupCount, 0, "No build-up should accumulate while stunned")
    }

    func testFreezeBuildupTriggersFrozenAtThreshold() {
        let hero = BattleTestFixtures.freezeAbilityHero(damage: 1)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.silentEnemy(maxHealth: 5)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        let events = BattleTestFixtures.advanceTicks(2, on: &battle)

        XCTAssertTrue(events.contains(effectKind: .preventionTriggered, keyword: .freeze))
    }

    func testStunBuildupProgressRendersInEffectSummary() {
        let hero = BattleTestFixtures.stunAbilityHero(damage: 1)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.silentEnemy(maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        BattleTestFixtures.advanceTicks(2, on: &battle)

        let summary = battle.enemyEffectSummaries.first { $0.keyword == .stun }
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary?.text.contains("Build-up") ?? false)
    }

    func testFreezeBuildupProgressRendersInEffectSummary() {
        let hero = BattleTestFixtures.freezeAbilityHero(damage: 1)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.silentEnemy(maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        BattleTestFixtures.advanceTicks(2, on: &battle)

        let summary = battle.enemyEffectSummaries.first { $0.keyword == .freeze }
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary?.text.contains("Build-up") ?? false)
    }

    func testThresholdIsCeilOfTwentyPercentOfMaxHealth() {
        let cases: [(maxHealth: Int, expectedThreshold: Int)] = [
            (7, 2),
            (20, 4),
            (50, 10),
            (100, 20)
        ]
        for (maxHealth, expectedThreshold) in cases {
            let hero = BattleTestFixtures.stunAbilityHero(damage: 1)
            let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
            let enemy = BattleTestFixtures.silentEnemy(maxHealth: maxHealth)
            var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

            BattleTestFixtures.advanceTicks(1, on: &battle)

            if let values = battle.firstEnemyEffect(matching: { $0.isPreventionBuildup })?.effect.preventionBuildupValues {
                XCTAssertEqual(values.2, expectedThreshold, "maxHealth=\(maxHealth)")
                XCTAssertGreaterThanOrEqual(values.1, 1, "Buildup of at least 1 expected for maxHealth=\(maxHealth)")
            } else {
                XCTFail("Expected buildup for maxHealth=\(maxHealth)")
            }
        }
    }

    func testCleanseStunRemovesBuildupOnHero() {
        let cleanseAbility = Ability(
            id: "test-cleanse",
            name: "Test Cleanse",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse Stunned.",
            targetedEffects: [TargetedEffect(.cleanse(.stun))]
        )
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            actionIntervalTicks: 1,
            abilities: [cleanseAbility]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 10)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .preventionBuildup(.stun, 5, 10), remainingTicks: 0)
            ]
        )

        BattleTestFixtures.advanceTicks(1, on: &battle)

        XCTAssertFalse(battle.hasHeroEffect { $0.isPreventionBuildup }, "Cleanse removed buildup")
    }
}
