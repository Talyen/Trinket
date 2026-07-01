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

    private func performActions(_ count: Int, on battle: inout BattleState) -> [BattleState.ActionEvent] {
        var allEvents: [BattleState.ActionEvent] = []
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
        var battle = BattleState(
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
        var battle = BattleState(
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
        var battle = BattleState(
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
        var battle = BattleState(
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
        var battle = BattleState(
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

    func testShieldBashStunsEnemyNextAction() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.shieldBash]
        )
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        _ = performActions(2, on: &battle)
        let events = performActions(4, on: &battle)

        XCTAssertTrue(events.contains { $0.effectKind == .preventionSkipped && $0.keyword == .stun })
        XCTAssertEqual(battle.heroHealth, hero.maxHealth)
    }

    func testPreventionDoesNotExpireFromTickDecay() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleState(
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
        var battle = BattleState(
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
        var battle = BattleState(
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
        XCTAssertTrue(events.contains { $0.effectKind == .instantHeal && $0.floatingText == "+3 Health" })
    }

    func testLeechHealsAttackerOnDamageDealt() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, actionIntervalTicks: 2, abilities: [.slash])
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 100)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, actionIntervalTicks: 100)
        var battle = BattleState(
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

        XCTAssertEqual(battle.heroHealth, 9)
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
        var battle = BattleState(
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
        var battle = BattleState(
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
        var battle = BattleState(
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
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

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
        let battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        XCTAssertEqual(battle.enemyAttackTarget.id, hero.id)
    }

    func testEnemyAttackTargetPrefersHigherHealthMember() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, maxHealth: 10)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        let battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        XCTAssertEqual(battle.enemyAttackTarget.id, hero.id)
    }

    func testEnemyTargetsPetWhenHeroDead() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero, maxHealth: 1)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet, maxHealth: 1)
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        _ = performActions(6, on: &battle)

        XCTAssertFalse(battle.isHeroAlive)
        XCTAssertEqual(battle.enemyAttackTarget.id, pet.id)
    }

    // MARK: - Summaries & logs

    func testEffectSummariesForShieldAndArmor() {
        let hero = passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        let battle = BattleState(
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
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        _ = battle.advanceOneStep()
        let events = battle.advanceOneStep().events

        XCTAssertTrue(events.contains { $0.floatingText == "+5 Block" })
        XCTAssertTrue(events.contains { $0.floatingText == "Cleanse Stun" } == false)
    }

    func testLegacyStatusApplicationPath() {
        let legacy = Ability(
            id: "legacy",
            name: "Legacy",
            tier: .basic,
            directDamage: 1,
            description: "Legacy",
            statusApplication: StatusApplication(keyword: .poison, durationTicks: 2, tickDamage: 2)
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [legacy])
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        XCTAssertTrue(battle.activeEnemyEffects.contains { $0.keyword == .poison })
    }
}
