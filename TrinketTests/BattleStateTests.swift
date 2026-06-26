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
        XCTAssertEqual(strike.tier, .basic)
        XCTAssertEqual(strike.damage, 1)
        XCTAssertEqual(strike.damageType, .physical)
        XCTAssertNil(strike.statusApplication)
        XCTAssertEqual(strike.summary, "1 Physical damage")
    }

    func testEmberDealsPhysicalDamageAndAppliesBurn() {
        let ember = Ability.ember

        XCTAssertEqual(ember.name, "Ember")
        XCTAssertEqual(ember.tier, .basic)
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
        XCTAssertEqual(battle.enemyHealth, 34)
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
        XCTAssertEqual(battle.enemyHealth, 33)
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
        XCTAssertEqual(battle.enemyHealth, 34)
        XCTAssertEqual(battle.activeEnemyStatuses.first?.keyword, .burn)
        XCTAssertEqual(battle.activeEnemyStatuses.first?.remainingTicks, 2)
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 1 damage next tick, 1 stack.")

        let firstBurnTick = battle.performNextAction()
        XCTAssertEqual(firstBurnTick.map(\.floatingText), ["Burn -1", "Wolf Strike -1"])
        XCTAssertEqual(battle.enemyHealth, 32)
        XCTAssertEqual(battle.activeEnemyStatuses.first?.remainingTicks, 1)

        let secondBurnTick = battle.performNextAction()
        XCTAssertEqual(secondBurnTick.map(\.floatingText), ["Burn -1", "Mage Ember -1"])
        XCTAssertEqual(battle.enemyHealth, 30)
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
        XCTAssertEqual(battle.enemyHealth, 29)
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 2 damage next tick, 2 stacks.")
        XCTAssertEqual(battle.log.contains { $0.text == "Training Slime takes 2 Burn damage." }, true)
    }

    func testCombatantsHaveTwoAbilityChoicesPerTierWithSelectedLoadout() {
        let mage = GameContent.heroes[2]

        XCTAssertEqual(mage.abilityChoices.basics.map(\.name), ["Ember", "Strike"])
        XCTAssertEqual(mage.abilityChoices.skills.map(\.name), ["Firebolt", "Kindle"])
        XCTAssertEqual(mage.abilityChoices.ultimates.map(\.name), ["Meteor", "Inferno"])
        XCTAssertEqual(mage.abilityLoadout.basic?.name, "Ember")
        XCTAssertEqual(mage.abilityLoadout.skill?.name, "Firebolt")
        XCTAssertEqual(mage.abilityLoadout.ultimate?.name, "Meteor")
        XCTAssertEqual(mage.abilities.map(\.tier), [.basic, .skill, .ultimate])
    }

    func testBasicSkillAndUltimateCadenceUsesPerCombatantTurns() {
        let hero = Combatant(
            id: "cadence-hero",
            name: "Cadence Hero",
            role: .hero,
            maxHealth: 10,
            abilityChoices: AbilityChoices(
                basics: [.strike, .shieldJab],
                skills: [.smite, .guardingBlow],
                ultimates: [.radiantCrash, .oathbreaker]
            )
        )
        let pet = Combatant(
            id: "cadence-pet",
            name: "Cadence Pet",
            role: .pet,
            maxHealth: 10,
            abilityChoices: AbilityChoices(
                basics: [.quickCut, .strike],
                skills: [.guardingBlow, .smite],
                ultimates: [.oathbreaker, .radiantCrash]
            )
        )
        let enemy = Combatant(id: "target", name: "Target", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        let abilityEvents = (0..<12).flatMap { _ in battle.performNextAction() }

        XCTAssertEqual(abilityEvents.map { "\($0.actorName) \($0.abilityName)" }, [
            "Cadence Hero Strike",
            "Cadence Pet Quick Cut",
            "Cadence Hero Strike",
            "Cadence Pet Quick Cut",
            "Cadence Hero Smite",
            "Cadence Pet Guarding Blow",
            "Cadence Hero Strike",
            "Cadence Pet Quick Cut",
            "Cadence Hero Strike",
            "Cadence Pet Quick Cut",
            "Cadence Hero Radiant Crash",
            "Cadence Pet Oathbreaker"
        ])
        XCTAssertEqual(battle.heroActionCount, 6)
        XCTAssertEqual(battle.petActionCount, 6)
        XCTAssertEqual(battle.actionCount, 12)
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
        XCTAssertEqual(battle.actionCount, 11)
        XCTAssertEqual(battle.tickCount, 11)
        XCTAssertEqual(allEvents.map(\.floatingText), [
            "Mage Ember -1",
            "Burn -1",
            "Drake Ember -1",
            "Burn -2",
            "Mage Ember -1",
            "Burn -2",
            "Drake Ember -1",
            "Burn -2",
            "Mage Firebolt -3",
            "Burn -2",
            "Drake Firebolt -3",
            "Burn -2",
            "Mage Ember -1",
            "Burn -2",
            "Drake Ember -1",
            "Burn -2",
            "Mage Ember -1",
            "Burn -2",
            "Drake Ember -1",
            "Burn -2",
            "Mage Meteor -6"
        ])
        XCTAssertEqual(battle.log.last?.text, "Training Slime is defeated.")

        let defeatedActions = battle.performNextAction()
        XCTAssertTrue(defeatedActions.isEmpty)
        XCTAssertEqual(battle.actionCount, 11)
        XCTAssertEqual(battle.tickCount, 11)
        XCTAssertEqual(battle.enemyHealth, 0)
    }

    func testBattleSimulatorRunsBattleToVictoryWithoutUI() {
        let result = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: GameContent.pets[2]
        )

        XCTAssertEqual(result.matchup.hero.name, "Mage")
        XCTAssertEqual(result.matchup.pet.name, "Drake")
        XCTAssertEqual(result.matchup.enemy.name, "Training Slime")
        XCTAssertEqual(result.outcome, BattleSimulationOutcome.victory)
        XCTAssertTrue(result.didWin)
        XCTAssertFalse(result.didHitTickLimit)
        XCTAssertEqual(result.finalEnemyHealth, 0)
        XCTAssertEqual(result.actionCount, 11)
        XCTAssertEqual(result.tickCount, 11)
        XCTAssertEqual(result.events.map(\.floatingText), [
            "Mage Ember -1",
            "Burn -1",
            "Drake Ember -1",
            "Burn -2",
            "Mage Ember -1",
            "Burn -2",
            "Drake Ember -1",
            "Burn -2",
            "Mage Firebolt -3",
            "Burn -2",
            "Drake Firebolt -3",
            "Burn -2",
            "Mage Ember -1",
            "Burn -2",
            "Drake Ember -1",
            "Burn -2",
            "Mage Ember -1",
            "Burn -2",
            "Drake Ember -1",
            "Burn -2",
            "Mage Meteor -6"
        ])
        XCTAssertEqual(result.metrics.totalDamage, 39)
        XCTAssertEqual(result.metrics.abilityDamage, 20)
        XCTAssertEqual(result.metrics.statusDamage, 19)
        XCTAssertEqual(result.metrics.actorDamage["Mage"], 13)
        XCTAssertEqual(result.metrics.actorDamage["Drake"], 7)
        XCTAssertEqual(result.metrics.actorDamage["Burn"], 19)
        XCTAssertEqual(result.metrics.keywordDamage[Keyword.physical], 20)
        XCTAssertEqual(result.metrics.keywordDamage[Keyword.burn], 19)
        XCTAssertEqual(result.log.last?.text, "Training Slime is defeated.")
    }

    func testBattleSimulatorStopsAtTickLimitWhenBattleCannotFinish() {
        let hero = Combatant(id: "watcher", name: "Watcher", role: .hero, maxHealth: 10, abilities: [])
        let pet = Combatant(id: "observer", name: "Observer", role: .pet, maxHealth: 10, abilities: [])
        let enemy = Combatant(id: "wall", name: "Wall", role: .enemy, maxHealth: 5, abilities: [])

        let result = BattleSimulator.run(
            hero: hero,
            pet: pet,
            enemy: enemy,
            maxTicks: 3
        )

        XCTAssertEqual(result.outcome, BattleSimulationOutcome.tickLimit)
        XCTAssertFalse(result.didWin)
        XCTAssertTrue(result.didHitTickLimit)
        XCTAssertEqual(result.tickCount, 3)
        XCTAssertEqual(result.actionCount, 0)
        XCTAssertEqual(result.finalEnemyHealth, 5)
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.log.last?.text, "Watcher and Observer face Wall.")
    }

    func testBattleSimulatorCanSkipCapturedEventsAndLogWhileKeepingMetrics() {
        let result = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: GameContent.pets[2],
            options: BattleSimulationOptions(recordsEvents: false, recordsLog: false)
        )

        XCTAssertTrue(result.didWin)
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertTrue(result.log.isEmpty)
        XCTAssertEqual(result.metrics.totalDamage, 39)
        XCTAssertEqual(result.metrics.abilityDamage, 20)
        XCTAssertEqual(result.metrics.statusDamage, 19)
    }

    func testBattleSimulatorSeededRunsAreRepeatable() {
        let matchup = BattleMatchup(
            hero: GameContent.heroes[2],
            pet: GameContent.pets[2]
        )
        let options = BattleSimulationOptions(maxTicks: 20, runCount: 5, seed: 42)

        let firstBatch = BattleSimulator.runBatch(matchups: [matchup], options: options)
        let secondBatch = BattleSimulator.runBatch(matchups: [matchup], options: options)

        XCTAssertEqual(firstBatch, secondBatch)
    }

    func testBattleSimulatorRunsEveryCurrentHeroPetPairInBulk() {
        let matchups = GameContent.heroes.flatMap { hero in
            GameContent.pets.map { pet in
                BattleMatchup(hero: hero, pet: pet)
            }
        }
        let options = BattleSimulationOptions(
            maxTicks: 30,
            runCount: 3,
            seed: 7,
            recordsEvents: false,
            recordsLog: false
        )

        let batchResults = BattleSimulator.runBatch(matchups: matchups, options: options)

        XCTAssertEqual(batchResults.count, 9)
        XCTAssertTrue(batchResults.allSatisfy { $0.options == options })
        XCTAssertTrue(batchResults.allSatisfy { $0.results.count == 3 })
        XCTAssertTrue(batchResults.allSatisfy { $0.summary.runCount == 3 })
        XCTAssertTrue(batchResults.allSatisfy { $0.summary.winCount == 3 })
        XCTAssertTrue(batchResults.allSatisfy { $0.summary.tickLimitCount == 0 })
        XCTAssertTrue(batchResults.allSatisfy { $0.summary.winRate == 1 })
        XCTAssertTrue(batchResults.allSatisfy { batchResult in
            batchResult.results.allSatisfy { $0.didWin }
        })
        XCTAssertTrue(batchResults.allSatisfy { $0.results.allSatisfy { $0.events.isEmpty && $0.log.isEmpty } })
    }

    func testBattleSimulatorSummarizesBatchResults() {
        let matchup = BattleMatchup(
            hero: GameContent.heroes[2],
            pet: GameContent.pets[2]
        )
        let options = BattleSimulationOptions(maxTicks: 20, runCount: 4, seed: 99)

        let batchResult = BattleSimulator.runBatch(matchups: [matchup], options: options).first

        XCTAssertEqual(batchResult?.summary.runCount, 4)
        XCTAssertEqual(batchResult?.summary.winCount, 4)
        XCTAssertEqual(batchResult?.summary.tickLimitCount, 0)
        XCTAssertEqual(batchResult?.summary.winRate ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(batchResult?.summary.averageTickCount ?? 0, 11, accuracy: 0.0001)
        XCTAssertEqual(batchResult?.summary.minimumTickCount, 11)
        XCTAssertEqual(batchResult?.summary.maximumTickCount, 11)
        XCTAssertEqual(batchResult?.summary.averageActionCount ?? 0, 11, accuracy: 0.0001)
        XCTAssertEqual(batchResult?.summary.averageFinalEnemyHealth ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(batchResult?.summary.averageTotalDamage ?? 0, 39, accuracy: 0.0001)
        XCTAssertEqual(batchResult?.summary.averageAbilityDamage ?? 0, 20, accuracy: 0.0001)
        XCTAssertEqual(batchResult?.summary.averageStatusDamage ?? 0, 19, accuracy: 0.0001)
    }

    func testBattleSimulatorHandlesEmptyBatchRuns() {
        let matchup = BattleMatchup(
            hero: GameContent.heroes[0],
            pet: GameContent.pets[0]
        )
        let options = BattleSimulationOptions(runCount: 0)

        let batchResult = BattleSimulator.runBatch(matchups: [matchup], options: options).first

        XCTAssertTrue(batchResult?.results.isEmpty == true)
        XCTAssertEqual(batchResult?.summary.runCount, 0)
        XCTAssertEqual(batchResult?.summary.winCount, 0)
        XCTAssertEqual(batchResult?.summary.tickLimitCount, 0)
        XCTAssertEqual(batchResult?.summary.winRate ?? -1, 0, accuracy: 0.0001)
        XCTAssertNil(batchResult?.summary.minimumTickCount)
        XCTAssertNil(batchResult?.summary.maximumTickCount)
    }
}
