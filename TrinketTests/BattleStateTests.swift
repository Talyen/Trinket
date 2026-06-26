import XCTest
@testable import Trinket

final class BattleStateTests: XCTestCase {
    func testBattleDebugConfigurationDefaultsToDisabled() {
        let configuration = BattleDebugConfiguration.parse(arguments: [])

        XCTAssertFalse(configuration.isEnabled)
        XCTAssertEqual(configuration.hero.name, "Mage")
        XCTAssertEqual(configuration.pet.name, "Drake")
        XCTAssertFalse(configuration.startsPaused)
    }

    func testBattleDebugConfigurationDefaultsWhenEnabled() {
        let configuration = BattleDebugConfiguration.parse(arguments: [
            "Trinket",
            "-battleDebugHarness",
            "enabled"
        ])

        XCTAssertTrue(configuration.isEnabled)
        XCTAssertEqual(configuration.hero.name, "Mage")
        XCTAssertEqual(configuration.pet.name, "Drake")
        XCTAssertTrue(configuration.startsPaused)
    }

    func testBattleDebugConfigurationParsesHeroAndPetByNameOrID() {
        let byName = BattleDebugConfiguration.parse(arguments: [
            "Trinket",
            "-battleDebugHarness",
            "enabled",
            "-battleDebugHero",
            "paladin",
            "-battleDebugPet",
            "Hawk"
        ])
        XCTAssertEqual(byName.hero.name, "Paladin")
        XCTAssertEqual(byName.pet.name, "Hawk")

        let byID = BattleDebugConfiguration.parse(arguments: [
            "Trinket",
            "-battleDebugHarness",
            "enabled",
            "-battleDebugHero",
            "MAGE",
            "-battleDebugPet",
            "drake"
        ])
        XCTAssertEqual(byID.hero.name, "Mage")
        XCTAssertEqual(byID.pet.name, "Drake")
    }

    func testBattleDebugConfigurationFallsBackForInvalidHeroAndPet() {
        let configuration = BattleDebugConfiguration.parse(arguments: [
            "Trinket",
            "-battleDebugHarness",
            "enabled",
            "-battleDebugHero",
            "NotAHero",
            "-battleDebugPet",
            "NotAPet"
        ])

        XCTAssertEqual(configuration.hero.name, "Mage")
        XCTAssertEqual(configuration.pet.name, "Drake")
    }

    func testBattleDebugConfigurationParsesPausedArgument() {
        let runningConfiguration = BattleDebugConfiguration.parse(arguments: [
            "Trinket",
            "-battleDebugHarness",
            "enabled",
            "-battleDebugPaused",
            "false"
        ])
        XCTAssertFalse(runningConfiguration.startsPaused)

        let pausedConfiguration = BattleDebugConfiguration.parse(arguments: [
            "Trinket",
            "-battleDebugHarness",
            "enabled",
            "-battleDebugPaused",
            "true"
        ])
        XCTAssertTrue(pausedConfiguration.startsPaused)
    }

    func testStrikeDealsOnePhysicalDamage() {
        let strike = Ability.strike

        XCTAssertEqual(strike.name, "Strike")
        XCTAssertEqual(strike.damage, 1)
        XCTAssertEqual(strike.damageType, .physical)
        XCTAssertNil(strike.statusApplication)
        XCTAssertEqual(strike.summary, "1 Physical damage")
    }

    func testEmberDealsPhysicalDamageAndAppliesBurn() {
        let ember = Ability.ember

        XCTAssertEqual(ember.name, "Ember")
        XCTAssertEqual(ember.damage, 1)
        XCTAssertEqual(ember.damageType, .physical)
        XCTAssertEqual(ember.statusApplication?.keyword, .burn)
        XCTAssertEqual(ember.statusApplication?.durationTicks, 2)
        XCTAssertEqual(ember.statusApplication?.tickDamage, 1)
        XCTAssertEqual(ember.summary, "1 Physical damage. Apply Burn 1 for 2 ticks.")
    }

    func testHeroAndPetActionsReduceEnemyHealth() {
        var battle = BattleState(hero: GameContent.heroes[0], pet: GameContent.pets[0])

        let heroActions = battle.performNextAction()
        let heroAction = heroActions.first
        XCTAssertEqual(battle.enemyHealth, 9)
        XCTAssertEqual(heroAction?.actorName, "Paladin")
        XCTAssertEqual(heroAction?.abilityName, "Strike")
        XCTAssertEqual(heroAction?.targetID, "training-slime")
        XCTAssertEqual(heroAction?.targetName, "Training Slime")
        XCTAssertEqual(heroAction?.amount, 1)
        XCTAssertEqual(heroAction?.keyword, .physical)
        XCTAssertEqual(heroAction?.floatingText, "Paladin Strike -1")
        XCTAssertEqual(battle.log.last?.text, "Paladin uses Strike for 1 Physical damage.")

        let petActions = battle.performNextAction()
        let petAction = petActions.first
        XCTAssertEqual(battle.enemyHealth, 8)
        XCTAssertEqual(petAction?.actorName, "Wolf")
        XCTAssertEqual(petAction?.abilityName, "Strike")
        XCTAssertEqual(petAction?.targetID, "training-slime")
        XCTAssertEqual(petAction?.targetName, "Training Slime")
        XCTAssertEqual(petAction?.amount, 1)
        XCTAssertEqual(petAction?.keyword, .physical)
        XCTAssertEqual(petAction?.floatingText, "Wolf Strike -1")
        XCTAssertEqual(battle.log.last?.text, "Wolf uses Strike for 1 Physical damage.")
    }

    func testBurnDealsDamageForTwoSubsequentTicksThenExpiresWhenNotReapplied() {
        var battle = BattleState(hero: GameContent.heroes[2], pet: GameContent.pets[0])

        let emberActions = battle.performNextAction()
        XCTAssertEqual(emberActions.map(\.floatingText), ["Mage Ember -1"])
        XCTAssertEqual(battle.enemyHealth, 9)
        XCTAssertEqual(battle.activeEnemyStatuses.first?.keyword, .burn)
        XCTAssertEqual(battle.activeEnemyStatuses.first?.remainingTicks, 2)
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 1 damage next tick, 1 stack.")

        let firstBurnTick = battle.performNextAction()
        XCTAssertEqual(firstBurnTick.map(\.floatingText), ["Burn -1", "Wolf Strike -1"])
        XCTAssertEqual(battle.enemyHealth, 7)
        XCTAssertEqual(battle.activeEnemyStatuses.first?.remainingTicks, 1)

        let secondBurnTick = battle.performNextAction()
        XCTAssertEqual(secondBurnTick.map(\.floatingText), ["Burn -1", "Mage Ember -1"])
        XCTAssertEqual(battle.enemyHealth, 5)
        XCTAssertEqual(battle.activeEnemyStatuses.count, 1)
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 1 damage next tick, 1 stack.")
        XCTAssertEqual(battle.log.contains { $0.text == "Training Slime takes 1 Burn damage." }, true)
    }

    func testMultipleBurnApplicationsStackAdditively() {
        var battle = BattleState(hero: GameContent.heroes[2], pet: GameContent.pets[2])

        _ = battle.performNextAction()
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 1 damage next tick, 1 stack.")

        let drakeTick = battle.performNextAction()
        XCTAssertEqual(drakeTick.map(\.floatingText), ["Burn -1", "Drake Ember -1"])
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 2 damage next tick, 2 stacks.")

        let stackedBurnTick = battle.performNextAction()
        XCTAssertEqual(stackedBurnTick.map(\.floatingText), ["Burn -2", "Mage Ember -1"])
        XCTAssertEqual(battle.enemyHealth, 4)
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 2 damage next tick, 2 stacks.")
        XCTAssertEqual(battle.log.contains { $0.text == "Training Slime takes 2 Burn damage." }, true)
    }

    func testDifferentBurnAmountsAndDurationsTickIndependently() {
        let hero = Combatant(id: "tester", name: "Tester", role: .hero, maxHealth: 10, abilities: [])
        let pet = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 10, abilities: [])
        let enemy = Combatant(
            id: "dummy",
            name: "Dummy",
            role: .enemy,
            maxHealth: 20,
            abilities: []
        )
        var battle = BattleState(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyStatuses: [
                ActiveStatus(id: 1, keyword: .burn, remainingTicks: 1, tickDamage: 3),
                ActiveStatus(id: 2, keyword: .burn, remainingTicks: 2, tickDamage: 1)
            ]
        )

        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 4 damage next tick, 2 stacks.")

        let stackedTick = battle.performNextAction()
        XCTAssertEqual(stackedTick.map(\.floatingText), ["Burn -4"])
        XCTAssertEqual(battle.activeEnemyStatuses.count, 1)
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 1 damage next tick, 1 stack.")

        let nextTick = battle.performNextAction()
        XCTAssertEqual(nextTick.map(\.floatingText), ["Burn -1"])
        XCTAssertTrue(battle.activeEnemyStatuses.isEmpty)
        XCTAssertNil(battle.enemyStatusSummaries.first)
    }

    func testMageAndDrakeBattleIsDeterministicAndStopsAtVictory() {
        var battle = BattleState(hero: GameContent.heroes[2], pet: GameContent.pets[2])
        var allEvents: [BattleState.ActionEvent] = []

        while !battle.isEnemyDefeated {
            allEvents.append(contentsOf: battle.performNextAction())
        }

        XCTAssertTrue(battle.isEnemyDefeated)
        XCTAssertEqual(battle.enemyHealth, 0)
        XCTAssertEqual(battle.actionCount, 4)
        XCTAssertEqual(battle.tickCount, 5)
        XCTAssertEqual(allEvents.map(\.floatingText), [
            "Mage Ember -1",
            "Burn -1",
            "Drake Ember -1",
            "Burn -2",
            "Mage Ember -1",
            "Burn -2",
            "Drake Ember -1",
            "Burn -2"
        ])
        XCTAssertEqual(battle.log.last?.text, "Training Slime is defeated.")

        let defeatedActions = battle.performNextAction()
        XCTAssertTrue(defeatedActions.isEmpty)
        XCTAssertEqual(battle.actionCount, 4)
        XCTAssertEqual(battle.tickCount, 5)
        XCTAssertEqual(battle.enemyHealth, 0)
    }
}
