import XCTest
@testable import Trinket

final class BattleStateTests: XCTestCase {
    private let mockDrake = Combatant(
        id: "drake",
        name: "Drake",
        role: .pet,
        maxHealth: 7,
        abilityChoices: AbilityChoices(
            basics: [.kindling, .rayOfFrost],
            skills: [.fireball, .cauterize],
            ultimates: [.meteor, .combustion]
        )
    )
    private var wolfPet: Combatant {
        GameContent.pets.first { $0.id == "wolf" }!
    }
    func testStrikeDealsOnePhysicalDamage() {
        let strike = Ability.slash

        XCTAssertEqual(strike.name, "Slash")
        XCTAssertEqual(strike.tier, .basic)
        XCTAssertEqual(strike.damage, 1)
        XCTAssertEqual(strike.damageType, .physical)
        XCTAssertNil(strike.statusApplication)
        XCTAssertEqual(strike.summary, "1 Physical damage")
    }

    func testEmberDealsPhysicalDamageAndAppliesBurn() {
        let ember = Ability.kindling

        XCTAssertEqual(ember.name, "Kindling")
        XCTAssertEqual(ember.tier, .basic)
        XCTAssertEqual(ember.damage, 1)
        XCTAssertEqual(ember.damageType, .burn)
        XCTAssertEqual(ember.statusApplication?.keyword, .burn)
        XCTAssertEqual(ember.statusApplication?.durationTicks, 2)
        XCTAssertEqual(ember.statusApplication?.tickDamage, 1)
        XCTAssertEqual(ember.summary, "1 Burn damage. Apply Burn 1 for 2 ticks.")
    }

    func testHeroAndPetActionsReduceEnemyHealth() {
        var battle = BattleState(hero: GameContent.heroes[0], pet: wolfPet)

        let heroActions = battle.performNextAction()
        let heroAction = heroActions.first
        XCTAssertEqual(battle.enemyHealth, 34)
        XCTAssertEqual(heroAction?.actorName, "Knight")
        XCTAssertEqual(heroAction?.abilityName, "Bash")
        XCTAssertEqual(heroAction?.targetID, "training-slime")
        XCTAssertEqual(heroAction?.targetName, "Training Slime")
        XCTAssertEqual(heroAction?.amount, 1)
        XCTAssertEqual(heroAction?.keyword, .physical)
        XCTAssertEqual(heroAction?.floatingText, "Knight Bash -1")
        XCTAssertEqual(battle.log.last?.text, "Knight uses Bash for 1 Physical damage.")

        let petActions = battle.performNextAction()
        let petAction = petActions.first
        XCTAssertEqual(battle.enemyHealth, 33)
        XCTAssertEqual(petAction?.actorName, "Wolf")
        XCTAssertEqual(petAction?.abilityName, "Slash")
        XCTAssertEqual(petAction?.targetID, "training-slime")
        XCTAssertEqual(petAction?.targetName, "Training Slime")
        XCTAssertEqual(petAction?.amount, 1)
        XCTAssertEqual(petAction?.keyword, .physical)
        XCTAssertEqual(petAction?.floatingText, "Wolf Slash -1")
        XCTAssertEqual(battle.log.last?.text, "Wolf uses Slash for 1 Physical damage.")
    }

    func testBurnDealsDamageForTwoSubsequentTicksThenExpiresWhenNotReapplied() {
        var battle = BattleState(hero: GameContent.heroes[2], pet: wolfPet)

        let emberActions = battle.performNextAction()
        XCTAssertEqual(emberActions.map(\.floatingText), ["Wizard Kindling -1"])
        XCTAssertEqual(battle.enemyHealth, 34)
        XCTAssertEqual(battle.activeEnemyStatuses.first?.keyword, .burn)
        XCTAssertEqual(battle.activeEnemyStatuses.first?.remainingTicks, 2)
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 1 damage next tick, 1 stack.")

        let firstBurnTick = battle.performNextAction()
        XCTAssertEqual(firstBurnTick.map(\.floatingText), ["Burn -1", "Wolf Slash -1"])
        XCTAssertEqual(battle.enemyHealth, 32)
        XCTAssertEqual(battle.activeEnemyStatuses.first?.remainingTicks, 1)

        let secondBurnTick = battle.performNextAction()
        XCTAssertEqual(secondBurnTick.map(\.floatingText), ["Burn -1", "Wizard Kindling -1"])
        XCTAssertEqual(battle.enemyHealth, 30)
        XCTAssertEqual(battle.activeEnemyStatuses.count, 1)
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 1 damage next tick, 1 stack.")
        XCTAssertEqual(battle.log.contains { $0.text == "Training Slime takes 1 Burn damage." }, true)
    }

    func testMultipleBurnApplicationsStackAdditively() {
        var battle = BattleState(hero: GameContent.heroes[2], pet: mockDrake)

        _ = battle.performNextAction()
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 1 damage next tick, 1 stack.")

        let drakeTick = battle.performNextAction()
        XCTAssertEqual(drakeTick.map(\.floatingText), ["Burn -1", "Drake Kindling -1"])
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 2 damage next tick, 2 stacks.")

        let stackedBurnTick = battle.performNextAction()
        XCTAssertEqual(stackedBurnTick.map(\.floatingText), ["Burn -2", "Wizard Kindling -1"])
        XCTAssertEqual(battle.enemyHealth, 29)
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 2 damage next tick, 2 stacks.")
        XCTAssertEqual(battle.log.contains { $0.text == "Training Slime takes 2 Burn damage." }, true)
    }

    func testCombatantsHaveTwoAbilityChoicesPerTierWithSelectedLoadout() {
        let wizard = GameContent.heroes[2]

        XCTAssertEqual(wizard.abilityChoices.basics.map(\.name), ["Kindling", "Ray of Frost"])
        XCTAssertEqual(wizard.abilityChoices.skills.map(\.name), ["Fireball", "Frostbolt"])
        XCTAssertEqual(wizard.abilityChoices.ultimates.map(\.name), ["Meteor", "Glacial Ward"])
        XCTAssertEqual(wizard.abilityLoadout.basic?.name, "Kindling")
        XCTAssertEqual(wizard.abilityLoadout.skill?.name, "Fireball")
        XCTAssertEqual(wizard.abilityLoadout.ultimate?.name, "Meteor")
        XCTAssertEqual(wizard.abilities.map(\.tier), [.basic, .skill, .ultimate])
    }

    func testRosterLoadoutConfiguresBattleAbilities() {
        let wizard = GameContent.heroes[2]
        var rosterState = PlayerRosterState.initial
        rosterState.setLoadout(
            AbilityLoadout(
                basic: .rayOfFrost,
                skill: .frostbolt,
                ultimate: .glacialWard
            ),
            for: wizard
        )

        let configuredWizard = rosterState.configuredCombatant(wizard)
        var battle = BattleState(hero: configuredWizard, pet: wolfPet)

        XCTAssertEqual(configuredWizard.abilityLoadout.basic?.name, "Ray of Frost")
        XCTAssertEqual(configuredWizard.abilityLoadout.skill?.name, "Frostbolt")
        XCTAssertEqual(configuredWizard.abilityLoadout.ultimate?.name, "Glacial Ward")
        XCTAssertEqual(battle.performNextAction().first?.floatingText, "Wizard Ray of Frost -1")
    }

    func testRosterProgressionFallsBackToInitialValues() {
        let customHero = Combatant(
            id: "new-hero",
            name: "New Hero",
            role: .hero,
            maxHealth: 5,
            abilities: [.slash]
        )
        let rosterState = PlayerRosterState.initial

        XCTAssertEqual(rosterState.progression(for: customHero), .initial)
        XCTAssertEqual(CombatantProgression.initial.level, 1)
        XCTAssertEqual(CombatantProgression.initial.currentXP, 0)
        XCTAssertEqual(CombatantProgression.initial.requiredXP, 100)
    }

    func testEquipmentLoadoutStoresItemIDsBySlot() {
        let item = GameContent.sampleInventoryItems[0]
        var loadout = EquipmentLoadout()

        loadout.equip(item)

        XCTAssertEqual(loadout.itemID(for: .weapon), item.id)
        XCTAssertNil(loadout.itemID(for: .armor))
    }

    func testMissingEquippedInventoryItemResolvesAsEmpty() {
        let knight = GameContent.heroes[0]
        var rosterState = PlayerRosterState.initial
        let missingLoadout = EquipmentLoadout(itemIDsBySlot: [
            .weapon: "missing-item"
        ])
        rosterState.setEquipmentLoadout(missingLoadout, for: knight)
        let emptyInventory = PlayerInventoryState(items: [])

        XCTAssertNil(rosterState.equippedItem(for: .weapon, combatant: knight, inventory: emptyInventory))
        XCTAssertEqual(rosterState.equipmentLoadout(for: knight).itemID(for: .weapon), "missing-item")
    }

    func testBasicSkillAndUltimateCadenceUsesPerCombatantTurns() {
        let hero = Combatant(
            id: "cadence-hero",
            name: "Cadence Hero",
            role: .hero,
            maxHealth: 10,
            abilityChoices: AbilityChoices(
                basics: [.slash, .shieldBash],
                skills: [.smite, .spikedShield],
                ultimates: [.blessedAegis, .crystalBulwark]
            )
        )
        let pet = Combatant(
            id: "cadence-pet",
            name: "Cadence Pet",
            role: .pet,
            maxHealth: 10,
            abilityChoices: AbilityChoices(
                basics: [.slash, .fangs],
                skills: [.serratedEdge, .venomFangs],
                ultimates: [.packTactics, .concussiveShot]
            )
        )
        let enemy = Combatant(id: "target", name: "Target", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        let abilityEvents = (0..<12).flatMap { _ in battle.performNextAction() }

        XCTAssertEqual(abilityEvents.map { "\($0.actorName) \($0.abilityName)" }, [
            "Cadence Hero Slash",
            "Cadence Pet Slash",
            "Cadence Hero Slash",
            "Cadence Pet Slash",
            "Cadence Hero Smite",
            "Cadence Pet Serrated Edge",
            "Cadence Hero Slash",
            "Cadence Pet Slash",
            "Cadence Hero Slash",
            "Cadence Pet Slash",
            "Cadence Hero Blessed Aegis",
            "Cadence Pet Pack Tactics"
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
        var battle = BattleState(hero: GameContent.heroes[2], pet: mockDrake)
        var allEvents: [BattleState.ActionEvent] = []

        while !battle.isEnemyDefeated {
            allEvents.append(contentsOf: battle.performNextAction())
        }

        XCTAssertTrue(battle.isEnemyDefeated)
        XCTAssertEqual(battle.enemyHealth, 0)
        XCTAssertEqual(battle.actionCount, 11)
        XCTAssertEqual(battle.tickCount, 11)
        XCTAssertEqual(allEvents.map(\.floatingText), [
            "Wizard Kindling -1",
            "Burn -1",
            "Drake Kindling -1",
            "Burn -2",
            "Wizard Kindling -1",
            "Burn -2",
            "Drake Kindling -1",
            "Burn -2",
            "Wizard Fireball -3",
            "Burn -2",
            "Drake Fireball -3",
            "Burn -2",
            "Wizard Kindling -1",
            "Burn -2",
            "Drake Kindling -1",
            "Burn -2",
            "Wizard Kindling -1",
            "Burn -2",
            "Drake Kindling -1",
            "Burn -2",
            "Wizard Meteor -6"
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
            pet: mockDrake
        )

        XCTAssertEqual(result.matchup.hero.name, "Wizard")
        XCTAssertEqual(result.matchup.pet.name, "Drake")
        XCTAssertEqual(result.matchup.enemy.name, "Training Slime")
        XCTAssertEqual(result.outcome, BattleSimulationOutcome.victory)
        XCTAssertTrue(result.didWin)
        XCTAssertFalse(result.didHitTickLimit)
        XCTAssertEqual(result.finalEnemyHealth, 0)
        XCTAssertEqual(result.actionCount, 11)
        XCTAssertEqual(result.tickCount, 11)
        XCTAssertEqual(result.events.map(\.floatingText), [
            "Wizard Kindling -1",
            "Burn -1",
            "Drake Kindling -1",
            "Burn -2",
            "Wizard Kindling -1",
            "Burn -2",
            "Drake Kindling -1",
            "Burn -2",
            "Wizard Fireball -3",
            "Burn -2",
            "Drake Fireball -3",
            "Burn -2",
            "Wizard Kindling -1",
            "Burn -2",
            "Drake Kindling -1",
            "Burn -2",
            "Wizard Kindling -1",
            "Burn -2",
            "Drake Kindling -1",
            "Burn -2",
            "Wizard Meteor -6"
        ])
        XCTAssertEqual(result.metrics.totalDamage, 39)
        XCTAssertEqual(result.metrics.abilityDamage, 20)
        XCTAssertEqual(result.metrics.statusDamage, 19)
        XCTAssertEqual(result.metrics.actorDamage["Wizard"], 13)
        XCTAssertEqual(result.metrics.actorDamage["Drake"], 7)
        XCTAssertEqual(result.metrics.actorDamage["Burn"], 19)
        XCTAssertNil(result.metrics.keywordDamage[Keyword.physical])
        XCTAssertEqual(result.metrics.keywordDamage[Keyword.burn], 39)
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
            pet: mockDrake,
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
            pet: mockDrake
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

        XCTAssertEqual(batchResults.count, 56)
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
            pet: mockDrake
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
            pet: wolfPet
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
