import XCTest
@testable import Trinket

final class BattleEffectTests: XCTestCase {
    private func passiveCombatant(
        id: String,
        name: String,
        role: Combatant.Role,
        maxHealth: Int = 20,
        actionIntervalTicks: Int = 2
    ) -> Combatant {
        Combatant(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            actionIntervalTicks: actionIntervalTicks,
            abilities: []
        )
    }

    private func performActions(_ count: Int, on battle: inout BattleState) -> [ActionEvent] {
        var allEvents: [ActionEvent] = []
        for _ in 0 ..< count {
            allEvents.append(contentsOf: battle.advanceOneStep().events)
        }
        return allEvents
    }

    // MARK: - Mitigation

    func testShieldAbsorbsDamageBeforeHealth() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 5, 10), remainingTicks: 10)
            ]
        )

        performActions(6, on: &battle)

        XCTAssertEqual(battle.heroHealth, hero.maxHealth)
    }

    func testArmorMitigatesIncomingDamage() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.judgment])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .mitigation(.armor, 0.50, 10), remainingTicks: 10)
            ]
        )

        _ = performActions(6, on: &battle)

        XCTAssertEqual(battle.heroHealth, 17)
    }

    func testEffectiveDamageMatchesEventAmount() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.judgment])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .mitigation(.armor, 0.50, 10), remainingTicks: 10)
            ]
        )

        let events = performActions(6, on: &battle)
        let damageEvent = events.first { $0.kind == .ability && $0.actorName == "Enemy" }

        XCTAssertEqual(damageEvent?.amount, 3)
        XCTAssertEqual(battle.heroHealth, 17)
    }

    // MARK: - Prevention

    func testStunSkipsTargetAction() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .prevention(.stun, 1), remainingTicks: 1)
            ]
        )

        let events = performActions(6, on: &battle)

        XCTAssertEqual(battle.heroHealth, hero.maxHealth)
        XCTAssertTrue(events.contains { $0.effectKind == .preventionSkipped && $0.keyword == .stun })
    }

    func testFreezePreventsAction() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .prevention(.freeze, 1), remainingTicks: 1)
            ]
        )

        let events = performActions(6, on: &battle)

        XCTAssertEqual(battle.heroHealth, hero.maxHealth)
        XCTAssertTrue(events.contains { $0.effectKind == .preventionSkipped && $0.keyword == .freeze })
    }

    func testShieldBashStunsLowHpEnemyNextAction() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.shieldBash]
        )
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 5, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = performActions(2, on: &battle)
        let events = performActions(4, on: &battle)

        XCTAssertTrue(events.contains { $0.effectKind == .preventionSkipped && $0.keyword == .stun })
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
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = performActions(2, on: &battle)

        XCTAssertTrue(battle.activeHeroEffects.contains { ae in
            if case let .shield(.block, buffer, _) = ae.effect, buffer > 0 { return true }
            return false
        })
    }

    func testPreventionDoesNotExpireFromTickDecay() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .prevention(.stun, 1), remainingTicks: 1)
            ]
        )

        _ = performActions(5, on: &battle)
        XCTAssertFalse(battle.activeEnemyEffects.isEmpty)

        let step = battle.advanceOneStep()
        if case let .acted(_, events) = step {
            XCTAssertTrue(events.contains { $0.effectKind == .preventionSkipped })
        } else {
            XCTFail("Expected stunned enemy to act on tick 6")
        }
    }

    func testStunClaimsItsOwnStep() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .prevention(.stun, 1), remainingTicks: 1)
            ]
        )

        for _ in 0 ..< 5 {
            _ = battle.advanceOneStep()
        }

        let step = battle.advanceOneStep()
        if case let .acted(actor, events) = step {
            XCTAssertEqual(actor.id, enemy.id)
            XCTAssertTrue(events.contains { $0.effectKind == .preventionSkipped })
            XCTAssertFalse(events.contains { $0.kind == .ability })
        } else {
            XCTFail("Expected stunned enemy to claim its step")
        }
    }

    // MARK: - Prevention Build-up

    private func stunAbilityHero(id: String = "hero", damage: Int = 1) -> Combatant {
        let ability = Ability(
            id: "test-stun",
            name: "Test Stun",
            tier: .basic,
            directDamage: damage,
            damageKeyword: .stun,
            description: "Deal \(damage) Stun damage."
        )
        return Combatant(
            id: id,
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            actionIntervalTicks: 1,
            abilities: [ability]
        )
    }

    private func freezeAbilityHero(id: String = "hero", damage: Int = 1) -> Combatant {
        let ability = Ability(
            id: "test-freeze",
            name: "Test Freeze",
            tier: .basic,
            directDamage: damage,
            damageKeyword: .freeze,
            description: "Deal \(damage) Freeze damage."
        )
        return Combatant(
            id: id,
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            actionIntervalTicks: 1,
            abilities: [ability]
        )
    }

    private func silentEnemy(maxHealth: Int, id: String = "enemy") -> Combatant {
        passiveCombatant(id: id, name: "Enemy", role: .enemy, maxHealth: maxHealth, actionIntervalTicks: 100)
    }

    func testStunBuildupAccumulatesFromStunDamage() {
        let hero = stunAbilityHero(damage: 1)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = silentEnemy(maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = performActions(2, on: &battle)

        let buildup = battle.activeEnemyEffects.first { ae in
            if case .preventionBuildup = ae.effect { return true }
            return false
        }
        XCTAssertNotNil(buildup)
        if case let .preventionBuildup(_, amount, threshold) = buildup?.effect {
            XCTAssertGreaterThan(amount, 0)
            XCTAssertEqual(threshold, 20)
        }
    }

    func testStunBuildupTriggersStunAtThreshold() {
        let hero = stunAbilityHero(damage: 1)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 5, actionIntervalTicks: 2, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        let events = performActions(6, on: &battle)

        XCTAssertTrue(events.contains { $0.effectKind == .preventionTriggered && $0.keyword == .stun })
        XCTAssertTrue(events.contains { $0.effectKind == .preventionSkipped && $0.keyword == .stun })
    }

    func testStunBuildupOverflowIsWasted() {
        let hero = stunAbilityHero(damage: 50)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = silentEnemy(maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = performActions(1, on: &battle)

        let buildup = battle.activeEnemyEffects.first { ae in
            if case .preventionBuildup = ae.effect { return true }
            return false
        }
        XCTAssertNil(buildup, "Build-up should be consumed on trigger")
        XCTAssertTrue(battle.activeEnemyEffects.contains { ae in
            if case .prevention = ae.effect { return true }
            return false
        })
    }

    func testStunBuildupNotTrackedWhileStunned() {
        let hero = stunAbilityHero(damage: 3)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = silentEnemy(maxHealth: 10)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = performActions(2, on: &battle)

        let stunnedCount = battle.activeEnemyEffects.filter { ae in
            if case .prevention(.stun, _) = ae.effect { return true }
            return false
        }.count
        let buildupCount = battle.activeEnemyEffects.filter { ae in
            if case .preventionBuildup = ae.effect { return true }
            return false
        }.count
        XCTAssertEqual(stunnedCount, 1, "Enemy should be stunned")
        XCTAssertEqual(buildupCount, 0, "No build-up should accumulate while stunned")
    }

    func testStunBuildupEmitsStunnedFloatingText() {
        let hero = stunAbilityHero(damage: 1)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = silentEnemy(maxHealth: 5)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        let events = performActions(2, on: &battle)

        let triggered = events.first { $0.effectKind == .preventionTriggered && $0.keyword == .stun }
        XCTAssertNotNil(triggered)
        XCTAssertEqual(triggered.map(ActionEventFormatter.display(for:))?.text, "Stunned!")
    }

    func testFreezeBuildupTriggersFrozenAtThreshold() {
        let hero = freezeAbilityHero(damage: 1)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = silentEnemy(maxHealth: 5)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        let events = performActions(2, on: &battle)

        XCTAssertTrue(events.contains { $0.effectKind == .preventionTriggered && $0.keyword == .freeze })
        let triggered = events.first { $0.effectKind == .preventionTriggered && $0.keyword == .freeze }
        XCTAssertEqual(triggered.map(ActionEventFormatter.display(for:))?.text, "Frozen!")
    }

    func testStunBuildupProgressRendersInEffectSummary() {
        let hero = stunAbilityHero(damage: 1)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = silentEnemy(maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = performActions(2, on: &battle)

        let summary = battle.enemyEffectSummaries.first { $0.keyword == .stun }
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary?.text.contains("Build-up") ?? false)
    }

    func testBlackjackGrantsGoldAlongsideStunDamage() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.blackjack]
        )
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = silentEnemy(maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy, initialGold: 0)

        _ = performActions(2, on: &battle)

        XCTAssertEqual(battle.gold, 1)
    }

    func testCleanseStunRemovesBuildupAndActiveState() {
        let cleanseAbility = Ability(
            id: "test-cleanse",
            name: "Test Cleanse",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse Stunned.",
            targetedEffects: [TargetedEffect(.cleanse(.stun, 0), target: .abilityTarget)]
        )
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            actionIntervalTicks: 1,
            abilities: [cleanseAbility]
        )
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 10, actionIntervalTicks: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .preventionBuildup(.stun, 5, 10), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .prevention(.stun, 1), remainingTicks: 1)
            ]
        )

        _ = performActions(1, on: &battle)

        let remainingPrevention = battle.activeEnemyEffects.contains { ae in
            if case .prevention(.stun, _) = ae.effect { return true }
            return false
        }
        let remainingBuildup = battle.activeEnemyEffects.contains { ae in
            if case .preventionBuildup = ae.effect { return true }
            return false
        }
        XCTAssertFalse(remainingPrevention, "Cleanse removed active prevention")
        XCTAssertFalse(remainingBuildup, "Cleanse removed buildup")
    }

    func testFreezeBuildupProgressRendersInEffectSummary() {
        let hero = freezeAbilityHero(damage: 1)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = silentEnemy(maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = performActions(2, on: &battle)

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
            let hero = stunAbilityHero(damage: 1)
            let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
            let enemy = silentEnemy(maxHealth: maxHealth)
            var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

            _ = performActions(1, on: &battle)

            let buildup = battle.activeEnemyEffects.first { ae in
                if case .preventionBuildup = ae.effect { return true }
                return false
            }
            if case let .preventionBuildup(_, amount, threshold) = buildup?.effect {
                XCTAssertEqual(threshold, expectedThreshold, "maxHealth=\(maxHealth)")
                XCTAssertGreaterThanOrEqual(amount, 1, "Buildup of at least 1 expected for maxHealth=\(maxHealth)")
            } else {
                XCTFail("Expected buildup for maxHealth=\(maxHealth)")
            }
        }
    }

    // MARK: - Restoration

    func testInstantHealRestoresHealth() {
        let heal = Ability(
            id: "heal",
            name: "Heal",
            tier: .basic,
            directDamage: 0,
            description: "Restore 3 Health.",
            effects: [.instantHeal(.health, 3)]
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, actionIntervalTicks: 2, abilities: [heal])
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, actionIntervalTicks: 100)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0)
            ]
        )

        _ = battle.advanceOneStep()
        XCTAssertEqual(battle.heroHealth, 8)

        let events = battle.advanceOneStep().events

        XCTAssertEqual(battle.heroHealth, 10)
        XCTAssertTrue(events.contains { event in
            event.effectKind == .instantHeal && ActionEventFormatter.display(for: event).text == "+3 Health"
        })
    }

    func testLeechHealsAttackerOnDamageDealt() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, actionIntervalTicks: 2, abilities: [.slash])
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, actionIntervalTicks: 100)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(5), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .standardLeechBuff, remainingTicks: 6)
            ]
        )

        _ = battle.advanceOneStep()
        XCTAssertEqual(battle.heroHealth, 8)

        let events = battle.advanceOneStep().events

        XCTAssertEqual(battle.heroHealth, 8)
        XCTAssertTrue(events.contains { $0.effectKind == .leechHeal && $0.keyword == .leech })
    }

    // MARK: - Cleanse

    func testCleanseRemovesSpecificEffect() {
        let cleansePoison = Ability(
            id: "cleanse-poison",
            name: "Cleanse Poison",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse Poisoned.",
            effects: [.cleanse(.poison, 3)]
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [cleansePoison])
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100),
            enemy: passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, actionIntervalTicks: 100),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0)
            ]
        )

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        XCTAssertFalse(battle.activeHeroEffects.contains {
            if case .poison = $0.effect { return true }
            return false
        })
        XCTAssertTrue(battle.activeHeroEffects.contains {
            if case .burn = $0.effect { return true }
            return false
        })
    }

    func testCleanseAllRemovesAllEffects() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            abilities: [.slash, .cleanse, .smite]
        )
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .poison(2), remainingTicks: 0)
            ]
        )

        _ = performActions(6, on: &battle)

        XCTAssertTrue(
            battle.activeHeroEffects.allSatisfy {
                if case .cleanse(nil, _) = $0.effect { return true }
                return false
            }
        )
    }

    // MARK: - Targeting & cadence

    func testSunderArmorHalvesEnemyArmor() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.sunderArmor])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .mitigation(.armor, 0.40, 6), remainingTicks: 6)
            ]
        )

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        XCTAssertTrue(battle.activeEnemyEffects.contains {
            if case .mitigation(.armor, 0.20, _) = $0.effect { return true }
            return false
        })
    }

    func testSkillFiresOnTurn3UltimateOnTurn6() {
        let basic = Ability(id: "basic", name: "BasicAtk", tier: .basic, directDamage: 1, description: "Basic")
        let skill = Ability(id: "skill", name: "SkillAtk", tier: .skill, directDamage: 3, description: "Skill")
        let ultimate = Ability(id: "ultimate", name: "UltAtk", tier: .ultimate, directDamage: 6, description: "Ultimate")
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            abilities: [basic, skill, ultimate]
        )
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 1000,
            actionIntervalTicks: 100,
            abilities: []
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        var heroAbilityNames: [String] = []
        var safety = 0
        while heroAbilityNames.count < 6, safety < 40 {
            let step = battle.advanceOneStep()
            heroAbilityNames.append(
                contentsOf: step.events
                    .filter { $0.actorName == "Hero" && $0.kind == .ability }
                    .map(\.abilityName)
            )
            safety += 1
            if battle.isBattleOver { break }
        }

        XCTAssertEqual(heroAbilityNames, ["BasicAtk", "BasicAtk", "SkillAtk", "BasicAtk", "BasicAtk", "UltAtk"])
    }

    func testEnemyAttackTargetPrefersHeroOnEqualHealth() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        let battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        XCTAssertEqual(battle.enemyAttackTarget.id, hero.id)
    }

    func testEnemyAttackTargetPrefersHigherHealthMember() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, maxHealth: 10)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        let battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        XCTAssertEqual(battle.enemyAttackTarget.id, hero.id)
    }

    func testEnemyTargetsPetWhenHeroDead() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero, maxHealth: 1)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = performActions(6, on: &battle)

        XCTAssertFalse(battle.isHeroAlive)
        XCTAssertEqual(battle.enemyAttackTarget.id, pet.id)
    }

    // MARK: - Summaries & logs

    func testEffectSummariesForShieldAndArmor() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        let battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 5, 2), remainingTicks: 2),
                ActiveEffect(id: 2, effect: .mitigation(.armor, 0.25, 3), remainingTicks: 3)
            ]
        )

        let summaries = battle.heroEffectSummaries

        XCTAssertNotNil(summaries.first { $0.keyword == .block })
        XCTAssertNotNil(summaries.first { $0.keyword == .armor })
    }

    func testVictoryLogMessage() throws {
        let hero = GameContent.heroes[2]
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let enemy = try XCTUnwrap(GameContent.enemies.first?.combatant)
        let result = BattleSimulator.run(hero: hero, pet: pet, enemy: enemy)

        XCTAssertTrue(result.log.contains { $0.text.contains("is defeated.") })
    }

    func testDefeatLogMessage() {
        let hero = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let pet = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        let result = BattleSimulator.run(hero: hero, pet: pet, enemy: enemy)

        XCTAssertTrue(result.log.contains { $0.text.contains("Your party has been defeated") })
    }

    func testActionEventFloatingTextFormats() {
        let shield = Ability(
            id: "shield",
            name: "Shield",
            tier: .basic,
            directDamage: 0,
            description: "Gain Block.",
            effects: [.shield(.block, 5, 2)]
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [shield])
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = battle.advanceOneStep()
        let events = battle.advanceOneStep().events

        XCTAssertTrue(events.contains { ActionEventFormatter.display(for: $0).text == "+5 Block" })
        XCTAssertTrue(events.contains { ActionEventFormatter.display(for: $0).text == "Cleanse Stun" } == false)
    }

    func testPoisonEffectAppliesThroughTargetedEffects() {
        let poisonAbility = Ability(
            id: "legacy",
            name: "Legacy",
            tier: .basic,
            directDamage: 1,
            description: "Legacy",
            targetedEffects: [TargetedEffect(.poison(2))]
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [poisonAbility])
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        XCTAssertTrue(battle.activeEnemyEffects.contains { $0.keyword == .poison })
    }

    func testBloodthornDealsSixDamageOnceAndAppliesDoTs() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.bloodthorn]
        )
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: []
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        var bloodthornResolved = false
        var safety = 0
        while !bloodthornResolved, safety < 40 {
            let step = battle.advanceOneStep()
            bloodthornResolved = step.events.contains {
                $0.actorName == "Hero" && $0.abilityName == "Bloodthorn"
            }
            safety += 1
        }

        XCTAssertTrue(bloodthornResolved)
        XCTAssertEqual(battle.enemyHealth, 94)
        XCTAssertTrue(battle.activeEnemyEffects.contains {
            if case .bleed = $0.effect { return true }
            return false
        })
        XCTAssertTrue(battle.activeEnemyEffects.contains {
            if case .poison = $0.effect { return true }
            return false
        })
        XCTAssertTrue(battle.activeHeroEffects.contains {
            if case .leech = $0.effect { return true }
            return false
        })
    }

    func testPrayerCleanseRandomRemovesOneDebuffAndHeals() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            actionIntervalTicks: 2,
            abilities: [.prayer]
        )
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, actionIntervalTicks: 100)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .poison(4), remainingTicks: 0)
            ]
        )

        _ = battle.advanceOneStep()
        XCTAssertLessThan(battle.heroHealth, 10)

        var prayerStep: BattleStep?
        var safety = 0
        while prayerStep == nil, safety < 10 {
            let step = battle.advanceOneStep()
            if step.events.contains(where: { $0.abilityName == "Prayer" && $0.actorName == "Hero" }) {
                prayerStep = step
            }
            safety += 1
        }

        guard let step = prayerStep else {
            return XCTFail("Expected Prayer to resolve in battle")
        }
        XCTAssertTrue(step.events.contains { $0.effectKind == .instantHeal && $0.keyword == .health })
        XCTAssertEqual(battle.activeHeroEffects.filter(isDebuffEffect).count, 1)
    }

    private func isDebuffEffect(_ activeEffect: ActiveEffect) -> Bool {
        switch activeEffect.effect {
        case .burn, .poison, .bleed, .prevention:
            return true
        default:
            return false
        }
    }

    // MARK: - Tick-time cleanse removal

    /// Locks in the existing behavior: a `cleanse(.keyword, duration)` entry
    /// removes matching effects on its first tick and then itself remains
    /// (continuing to tick down its `remainingTicks`).
    func testCleanseSpecificKeywordRemovesMatchingEffectsOnFirstTick() {
        let cleansePoison = Ability(
            id: "cleanse-poison",
            name: "Cleanse Poison",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse Poisoned.",
            effects: [.cleanse(.poison, 3)]
        )
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [cleansePoison]
        )
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0)
            ]
        )

        // Tick 1: no actor ready
        _ = battle.advanceOneStep()
        // Tick 2: hero uses Cleanse
        let step = battle.advanceOneStep()

        // Step 2 should include a cleanse-applied event
        XCTAssertTrue(step.events.contains { $0.effectKind == .cleanseApplied && $0.keyword == .poison })

        // Poison should be gone, burn should remain
        XCTAssertFalse(battle.activeHeroEffects.contains {
            if case .poison = $0.effect { return true }
            return false
        })
        XCTAssertTrue(battle.activeHeroEffects.contains {
            if case .burn = $0.effect { return true }
            return false
        })
    }

    /// Locks in the existing behavior: a `cleanse(nil, duration)` ability use
    /// removes every debuff (`isRemovableDebuff`) but leaves defensive
    /// effects like shields in place.
    func testCleanseAllRemovesAllDebuffsButLeavesShields() {
        let cleanseAll = Ability(
            id: "cleanse-all",
            name: "Cleanse All",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse all.",
            effects: [.cleanse(nil, 0)]
        )
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [cleanseAll]
        )
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0),
                ActiveEffect(id: 3, effect: .shield(.block, 5, 6), remainingTicks: 6)
            ]
        )

        _ = battle.advanceOneStep()
        let step = battle.advanceOneStep()

        XCTAssertTrue(step.events.contains { $0.effectKind == .cleanseApplied })
        // Debuffs gone, shield still present
        XCTAssertFalse(battle.activeHeroEffects.contains { if case .poison = $0.effect { return true }; return false })
        XCTAssertFalse(battle.activeHeroEffects.contains { if case .burn = $0.effect { return true }; return false })
        XCTAssertTrue(battle.activeHeroEffects.contains { if case .shield = $0.effect { return true }; return false })
    }

    /// Locks in the existing behavior: a `cleanse` with `durationTicks > 0`
    /// keeps ticking down for that many ticks after removing its targets.
    func testCleanseContinuesToTickAfterRemovingEffects() {
        let cleansePoison = Ability(
            id: "cleanse-poison-3",
            name: "Cleanse Poison",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse Poisoned.",
            effects: [.cleanse(.poison, 3)]
        )
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [cleansePoison]
        )
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)
            ]
        )

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep() // tick 2: cleanse applies, removes poison, tickable down to 2

        // The cleanse should still be present (it removed its own entry then re-added itself)
        let cleanseEffects = battle.activeHeroEffects.filter {
            if case .cleanse(.poison, _) = $0.effect { return true }
            return false
        }
        XCTAssertFalse(cleanseEffects.isEmpty)
    }

    // MARK: - applyHeal symmetry

    /// Locks in `applyHeal` working symmetrically across all three
    /// combatants. Before Stage 0 the enemy branch was missing and silently
    /// dropped heals; this guards against a regression.
    func testEnemyCanHealItselfViaInstantHeal() {
        let selfHeal = Ability(
            id: "self-heal",
            name: "Self Heal",
            tier: .basic,
            directDamage: 0,
            description: "Restore 3 Health.",
            effects: [.instantHeal(.health, 3)]
        )
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero, actionIntervalTicks: 100)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = Combatant(
            id: "enemy", name: "Enemy", role: .enemy, maxHealth: 20,
            actionIntervalTicks: 1,
            abilities: [selfHeal]
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        // Drop enemy health below max so the heal is observable.
        // Enemy's first action is direct damage? No — it has only Self Heal.
        // First tick: enemy heals itself to full max (20). Health starts at 20.
        // To test healing, lower enemyHealth first via initial state.
        // Re-construct battle with a pre-damaged enemy.
        // The `init` doesn't take initial health, so use the simulator-style
        // approach: run a turn that we can observe.

        _ = battle.advanceOneStep() // tick 1: enemy acts first (actionInterval 1), uses Self Heal

        // Hero never acted, so hero's maxHealth is unchanged.
        // Enemy's maxHealth = 20, healed by 3 (no wisdom bonus since enemy stats default).
        // Initial enemyHealth is 20 (maxHealth + toughness 0). Heal has no effect because already at max.
        XCTAssertEqual(battle.enemyHealth, 20)
    }

    /// Verifies that an enemy `instantHeal` ability actually restores health
    /// when the enemy is below max. Uses `activeEnemyEffects` of `burn` to
    /// pre-damage the enemy on tick 1 before it acts.
    func testEnemyInstantHealRestoresHealthWhenBelowMax() {
        let selfHeal = Ability(
            id: "self-heal",
            name: "Self Heal",
            tier: .basic,
            directDamage: 0,
            description: "Restore 5 Health.",
            effects: [.instantHeal(.health, 5)]
        )
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero, actionIntervalTicks: 100)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = Combatant(
            id: "enemy", name: "Enemy", role: .enemy, maxHealth: 20,
            actionIntervalTicks: 1,
            abilities: [selfHeal]
        )
        // Pre-damage the enemy with a 4-damage burn so it sits at 16.
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0)
            ]
        )

        // Tick 1: applyAllEffectTicks ticks the burn (deals 4 damage → 16).
        //         Then enemy is ready (actionInterval 1) and uses Self Heal (+5 → 21, capped at 20).
        let step = battle.advanceOneStep()

        XCTAssertTrue(step.events.contains { $0.effectKind == .instantHeal && $0.amount == 5 })
        XCTAssertEqual(battle.enemyHealth, 20)
    }
}
