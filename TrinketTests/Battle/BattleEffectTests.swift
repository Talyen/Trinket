import XCTest
@testable import Trinket

final class BattleEffectTests: XCTestCase {
    private func passiveCombatant(
        id: String,
        name: String,
        role: Combatant.Role,
        maxHealth: Int = 20
    ) -> Combatant {
        Combatant(id: id, name: name, role: role, maxHealth: maxHealth, abilities: [])
    }

    private func performActions(_ count: Int, on battle: inout BattleState) -> [BattleState.ActionEvent] {
        var allEvents: [BattleState.ActionEvent] = []
        for _ in 0..<count {
            allEvents.append(contentsOf: battle.performNextAction())
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

        performActions(3, on: &battle)

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

        _ = performActions(3, on: &battle)

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
                ActiveEffect(id: 1, effect: .prevention(.stun, 1), remainingTicks: 10)
            ]
        )

        let events = performActions(3, on: &battle)

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
                ActiveEffect(id: 1, effect: .prevention(.freeze, 1), remainingTicks: 10)
            ]
        )

        let events = performActions(3, on: &battle)

        XCTAssertEqual(battle.heroHealth, hero.maxHealth)
        XCTAssertTrue(events.contains { $0.effectKind == .preventionSkipped && $0.keyword == .freeze })
    }

    // MARK: - Restoration

    func testInstantHealRestoresHealth() {
        let heal = Ability(
            id: "heal",
            name: "Heal",
            tier: .basic,
            directDamage: 0,
            effects: [.instantHeal(.health, 3)]
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [heal])
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleState(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .damageOverTime(.burn, 4, 1), remainingTicks: 1)
            ]
        )

        let events = battle.performNextAction()

        XCTAssertEqual(battle.heroHealth, 9)
        XCTAssertTrue(events.contains { $0.effectKind == .instantHeal && $0.floatingText == "+3 Health" })
    }

    func testLeechHealsAttackerOnDamageDealt() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [.slash])
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleState(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .damageOverTime(.burn, 5, 1), remainingTicks: 1),
                ActiveEffect(id: 2, effect: .leech(.leech, 0.25, 3), remainingTicks: 3)
            ]
        )

        let events = battle.performNextAction()

        XCTAssertEqual(battle.heroHealth, 6)
        XCTAssertTrue(events.contains { $0.effectKind == .leechHeal && $0.keyword == .leech })
    }

    // MARK: - Cleanse

    func testCleanseRemovesSpecificEffect() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [.smellingSalts])
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleState(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .prevention(.stun, 2), remainingTicks: 2),
                ActiveEffect(id: 2, effect: .damageOverTime(.burn, 1, 2), remainingTicks: 2)
            ]
        )

        _ = battle.performNextAction()

        XCTAssertFalse(battle.activeHeroEffects.contains { $0.keyword == .stun })
        XCTAssertTrue(battle.activeHeroEffects.contains { $0.keyword == .burn })
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
                ActiveEffect(id: 1, effect: .damageOverTime(.burn, 1, 2), remainingTicks: 2),
                ActiveEffect(id: 2, effect: .damageOverTime(.poison, 1, 2), remainingTicks: 2)
            ]
        )

        _ = performActions(3, on: &battle)

        XCTAssertTrue(
            battle.activeHeroEffects.allSatisfy {
                if case .cleanse(nil, _) = $0.effect { return true }
                return false
            }
        )
    }

    // MARK: - Targeting & cadence

    func testSkillFiresOnTurn3UltimateOnTurn6() {
        let basic = Ability(id: "basic", name: "BasicAtk", tier: .basic, directDamage: 1)
        let skill = Ability(id: "skill", name: "SkillAtk", tier: .skill, directDamage: 3)
        let ultimate = Ability(id: "ultimate", name: "UltAtk", tier: .ultimate, directDamage: 6)
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            abilities: [basic, skill, ultimate]
        )
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 1000)
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        var heroAbilityNames: [String] = []
        for _ in 0..<6 {
            let events = battle.performNextAction()
            heroAbilityNames.append(
                contentsOf: events
                    .filter { $0.actorName == "Hero" && $0.kind == .ability }
                    .map(\.abilityName)
            )
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

        _ = performActions(3, on: &battle)

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

    func testVictoryLogMessage() {
        let hero = GameContent.heroes[2]
        let pet = GameContent.pets.first { $0.id == "wolf" }!
        let enemy = GameContent.enemies.first!.combatant
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
            effects: [.shield(.block, 5, 2)]
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [shield])
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        let events = battle.performNextAction()

        XCTAssertTrue(events.contains { $0.floatingText == "+5 Block" })
        XCTAssertTrue(events.contains { $0.floatingText == "Cleanse Stun" } == false)
    }

    func testLegacyStatusApplicationPath() {
        let legacy = Ability(
            id: "legacy",
            name: "Legacy",
            tier: .basic,
            directDamage: 1,
            statusApplication: StatusApplication(keyword: .poison, durationTicks: 2, tickDamage: 2)
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [legacy])
        let pet = passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        _ = battle.performNextAction()

        XCTAssertTrue(battle.activeEnemyEffects.contains { $0.keyword == .poison })
    }
}
