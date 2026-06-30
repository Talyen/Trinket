import XCTest
@testable import Trinket

final class BattleStateTests: XCTestCase {
    private let defaultTestEnemy = GameContent.enemies.first!.combatant

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
        var battle = BattleState(hero: GameContent.heroes[0], pet: wolfPet, enemy: defaultTestEnemy)

        let tick1 = battle.performNextAction()
        XCTAssertEqual(battle.enemyHealth, 33)
        XCTAssertEqual(tick1.map(\.floatingText), ["Knight Bash -1", "Wolf Slash -1"])
        XCTAssertEqual(tick1[0].actorName, "Knight")
        XCTAssertEqual(tick1[0].abilityName, "Bash")
        XCTAssertEqual(tick1[0].targetID, "goblin")
        XCTAssertEqual(tick1[0].targetName, "Goblin")
        XCTAssertEqual(tick1[0].amount, 1)
        XCTAssertEqual(tick1[0].keyword, .physical)
        XCTAssertEqual(tick1[0].floatingText, "Knight Bash -1")
        XCTAssertEqual(tick1[1].actorName, "Wolf")
        XCTAssertEqual(tick1[1].abilityName, "Slash")
        XCTAssertEqual(tick1[1].floatingText, "Wolf Slash -1")

        let tick2 = battle.performNextAction()
        XCTAssertEqual(battle.enemyHealth, 31)
        XCTAssertEqual(tick2.map(\.floatingText), ["Knight Bash -1", "Wolf Slash -1"])
    }

    func testBurnDealsDamageForTwoSubsequentTicksThenExpiresWhenNotReapplied() {
        let hero = Combatant(id: "burn-tester", name: "Burn Tester", role: .hero, maxHealth: 10, abilities: [])
        let pet = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 10, abilities: [])
        let enemy = Combatant(id: "dummy", name: "Dummy", role: .enemy, maxHealth: 20, abilities: [])
        var battle = BattleState(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyStatuses: [ActiveStatus(id: 1, keyword: .burn, remainingTicks: 3, tickDamage: 1)]
        )

        XCTAssertEqual(battle.activeEnemyStatuses.first?.remainingTicks, 3)
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 1 damage next tick, 1 stack.")

        let firstTick = battle.performNextAction()
        XCTAssertEqual(firstTick.map(\.floatingText), ["Burn -1"])
        XCTAssertEqual(battle.enemyHealth, 19)
        XCTAssertEqual(battle.activeEnemyStatuses.first?.remainingTicks, 2)

        let secondTick = battle.performNextAction()
        XCTAssertEqual(secondTick.map(\.floatingText), ["Burn -1"])
        XCTAssertEqual(battle.enemyHealth, 18)
        XCTAssertEqual(battle.activeEnemyStatuses.first?.remainingTicks, 1)

        let thirdTick = battle.performNextAction()
        XCTAssertEqual(thirdTick.map(\.floatingText), ["Burn -1"])
        XCTAssertEqual(battle.enemyHealth, 17)
        XCTAssertTrue(battle.activeEnemyStatuses.isEmpty)
        XCTAssertNil(battle.enemyStatusSummaries.first)
        XCTAssertEqual(battle.log.contains { $0.text == "Dummy takes 1 Burn damage." }, true)
    }

    func testMultipleBurnApplicationsStackAdditively() {
        var battle = BattleState(hero: GameContent.heroes[2], pet: mockDrake, enemy: defaultTestEnemy)

        let tick1 = battle.performNextAction()
        XCTAssertEqual(battle.enemyHealth, 33)
        XCTAssertEqual(tick1.map(\.floatingText), ["Wizard Kindling -1", "Drake Kindling -1"])
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 2 damage next tick, 2 stacks.")

        let tick2 = battle.performNextAction()
        XCTAssertEqual(tick2.map(\.floatingText), ["Burn -2", "Wizard Kindling -1", "Drake Kindling -1"])
        XCTAssertEqual(battle.enemyHealth, 29)
        XCTAssertEqual(battle.enemyStatusSummaries.first?.text, "Burn: 4 damage next tick, 4 stacks.")

        let tick3 = battle.performNextAction()
        XCTAssertEqual(tick3.map(\.floatingText), ["Burn -4", "Wizard Fireball -3", "Drake Fireball -3", "Goblin Slash -1"])
        XCTAssertEqual(battle.enemyHealth, 19)
        XCTAssertEqual(battle.log.contains { $0.text == "Goblin takes 4 Burn damage." }, true)
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
        var battle = BattleState(hero: configuredWizard, pet: wolfPet, enemy: defaultTestEnemy)

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

    func testLongswordBasicItemExposesArtAndDisplayName() {
        let item = GameContent.sampleInventoryItems.first { $0.id == "longsword-basic" }

        XCTAssertNotNil(item)
        XCTAssertEqual(item?.displayName, "Longsword")
        XCTAssertEqual(item?.rarity, .basic)
        XCTAssertEqual(item?.baseType.slot, .weapon)
        XCTAssertNotNil(item?.artReference)
        XCTAssertEqual(item?.artReference?.imageName, "item_longsword_basic")
        XCTAssertEqual(item?.affixes, [.placeholder])
    }

    func testSampleInventoryCoversAllRaritiesForEveryBaseType() {
        let baseIDs = Set(GameContent.itemBaseTypes.map(\.id))
        let itemIDs = Set(GameContent.sampleInventoryItems.map(\.id))

        for base in baseIDs {
            for rarity in Rarity.allCases {
                XCTAssertTrue(
                    itemIDs.contains("\(base)-\(rarity.rawValue)"),
                    "Missing sample item for \(base) at \(rarity.label) rarity"
                )
            }
        }
    }

    func testKnightStartsWithLongswordAndPlateArmor() {
        let knight = GameContent.heroes.first { $0.id == "knight" }!
        let loadout = PlayerRosterState.initial.equipmentLoadout(for: knight)
        let inventory = PlayerInventoryState.initial

        XCTAssertEqual(loadout.itemID(for: .weapon), "longsword-basic")
        XCTAssertEqual(loadout.itemID(for: .armor), "plate_armor-basic")
        XCTAssertNil(loadout.itemID(for: .trinket))

        let weapon = inventory.item(matching: loadout.itemID(for: .weapon))
        let armor = inventory.item(matching: loadout.itemID(for: .armor))
        XCTAssertEqual(weapon?.displayName, "Longsword")
        XCTAssertEqual(weapon?.rarity, .basic)
        XCTAssertEqual(armor?.displayName, "Plate Armor")
        XCTAssertEqual(armor?.rarity, .basic)
    }

    func testSlotBackgroundsAreWiredForEachItemSlot() {
        for slot in ItemSlot.allCases {
            XCTAssertNotNil(slot.slotBackgroundReference, "Missing slot background for \(slot.rawValue)")
        }
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
            "Cadence Pet Pack Tactics",
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
        XCTAssertEqual(battle.heroActionCount, 12)
        XCTAssertEqual(battle.petActionCount, 12)
        XCTAssertEqual(battle.actionCount, 24)
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
        var battle = BattleState(hero: GameContent.heroes[2], pet: mockDrake, enemy: defaultTestEnemy)
        var allEvents: [BattleState.ActionEvent] = []

        while !battle.isEnemyDefeated {
            allEvents.append(contentsOf: battle.performNextAction())
        }

        XCTAssertTrue(battle.isEnemyDefeated)
        XCTAssertEqual(battle.enemyHealth, 0)
        XCTAssertEqual(battle.actionCount, 13)
        XCTAssertEqual(battle.tickCount, 6)
        XCTAssertEqual(allEvents.map(\.floatingText), [
            "Wizard Kindling -1",
            "Drake Kindling -1",
            "Burn -2",
            "Wizard Kindling -1",
            "Drake Kindling -1",
            "Burn -4",
            "Wizard Fireball -3",
            "Drake Fireball -3",
            "Goblin Slash -1",
            "Burn -4",
            "Wizard Kindling -1",
            "Drake Kindling -1",
            "Burn -4",
            "Wizard Kindling -1",
            "Drake Kindling -1",
            "Burn -4",
            "Wizard Meteor -6",
            "Drake Meteor -6"
        ])
        XCTAssertEqual(battle.log.last?.text, "Goblin is defeated.")

        let defeatedActions = battle.performNextAction()
        XCTAssertTrue(defeatedActions.isEmpty)
        XCTAssertEqual(battle.actionCount, 13)
        XCTAssertEqual(battle.tickCount, 6)
        XCTAssertEqual(battle.enemyHealth, 0)
    }

    func testBattleSimulatorRunsBattleToVictoryWithoutUI() {
        let result = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: mockDrake,
            enemy: defaultTestEnemy
        )

        XCTAssertEqual(result.matchup.hero.name, "Wizard")
        XCTAssertEqual(result.matchup.pet.name, "Drake")
        XCTAssertEqual(result.matchup.enemy.name, "Goblin")
        XCTAssertEqual(result.outcome, BattleSimulationOutcome.victory)
        XCTAssertTrue(result.didWin)
        XCTAssertFalse(result.didHitTickLimit)
        XCTAssertEqual(result.finalEnemyHealth, 0)
        XCTAssertEqual(result.actionCount, 13)
        XCTAssertEqual(result.tickCount, 6)
        XCTAssertEqual(result.events.map(\.floatingText), [
            "Wizard Kindling -1",
            "Drake Kindling -1",
            "Burn -2",
            "Wizard Kindling -1",
            "Drake Kindling -1",
            "Burn -4",
            "Wizard Fireball -3",
            "Drake Fireball -3",
            "Goblin Slash -1",
            "Burn -4",
            "Wizard Kindling -1",
            "Drake Kindling -1",
            "Burn -4",
            "Wizard Kindling -1",
            "Drake Kindling -1",
            "Burn -4",
            "Wizard Meteor -6",
            "Drake Meteor -6"
        ])
        XCTAssertEqual(result.metrics.totalDamage, 45)
        XCTAssertEqual(result.metrics.abilityDamage, 27)
        XCTAssertEqual(result.metrics.statusDamage, 18)
        XCTAssertEqual(result.metrics.actorDamage["Wizard"], 13)
        XCTAssertEqual(result.metrics.actorDamage["Drake"], 13)
        XCTAssertEqual(result.metrics.actorDamage["Goblin"], 1)
        XCTAssertEqual(result.metrics.actorDamage["Burn"], 18)
        XCTAssertEqual(result.metrics.keywordDamage[Keyword.physical], 1)
        XCTAssertEqual(result.metrics.keywordDamage[Keyword.burn], 44)
        XCTAssertEqual(result.log.last?.text, "Goblin is defeated.")
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
            enemy: defaultTestEnemy,
            options: BattleSimulationOptions(recordsEvents: false, recordsLog: false)
        )

        XCTAssertTrue(result.didWin)
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertTrue(result.log.isEmpty)
        XCTAssertEqual(result.metrics.totalDamage, 45)
        XCTAssertEqual(result.metrics.abilityDamage, 27)
        XCTAssertEqual(result.metrics.statusDamage, 18)
    }

    func testBattleSimulatorSeededRunsAreRepeatable() {
        let matchup = BattleMatchup(
            hero: GameContent.heroes[2],
            pet: mockDrake,
            enemy: defaultTestEnemy
        )
        let options = BattleSimulationOptions(maxTicks: 20, runCount: 5, seed: 42)

        let firstBatch = BattleSimulator.runBatch(matchups: [matchup], options: options)
        let secondBatch = BattleSimulator.runBatch(matchups: [matchup], options: options)

        XCTAssertEqual(firstBatch, secondBatch)
    }

    func testBattleSimulatorRunsEveryCurrentHeroPetPairInBulk() {
        let matchups = GameContent.heroes.flatMap { hero in
            GameContent.pets.map { pet in
                BattleMatchup(hero: hero, pet: pet, enemy: defaultTestEnemy)
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
            pet: mockDrake,
            enemy: defaultTestEnemy
        )
        let options = BattleSimulationOptions(maxTicks: 20, runCount: 4, seed: 99)

        let batchResult = BattleSimulator.runBatch(matchups: [matchup], options: options).first

        XCTAssertEqual(batchResult?.summary.runCount, 4)
        XCTAssertEqual(batchResult?.summary.winCount, 4)
        XCTAssertEqual(batchResult?.summary.tickLimitCount, 0)
        XCTAssertEqual(batchResult?.summary.winRate ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(batchResult?.summary.averageTickCount ?? 0, 6, accuracy: 0.0001)
        XCTAssertEqual(batchResult?.summary.minimumTickCount, 6)
        XCTAssertEqual(batchResult?.summary.maximumTickCount, 6)
        XCTAssertEqual(batchResult?.summary.averageActionCount ?? 0, 13, accuracy: 0.0001)
        XCTAssertEqual(batchResult?.summary.averageFinalEnemyHealth ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(batchResult?.summary.averageTotalDamage ?? 0, 45, accuracy: 0.0001)
        XCTAssertEqual(batchResult?.summary.averageAbilityDamage ?? 0, 27, accuracy: 0.0001)
        XCTAssertEqual(batchResult?.summary.averageStatusDamage ?? 0, 18, accuracy: 0.0001)
    }

    func testEnemyAttackScheduleMatchesIntervalConstant() {
        let battle = BattleState(hero: GameContent.heroes[0], pet: wolfPet)
        XCTAssertEqual(BattleState.defaultEnemyAttackIntervalTicks, 3)
        XCTAssertEqual(BattleState.defaultHeroAttackIntervalTicks, 1)
        XCTAssertEqual(BattleState.defaultPetAttackIntervalTicks, 1)
    }

    func testEnemyTargetsHeroOnHPTie() {
        let hero = Combatant(id: "h1", name: "Hero", role: .hero, maxHealth: 10, abilities: [])
        let pet = Combatant(id: "p1", name: "Pet", role: .pet, maxHealth: 10, abilities: [])
        let enemy = Combatant(id: "e1", name: "Enemy", role: .enemy, maxHealth: 5, abilities: [.slash])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        _ = battle.performNextAction()
        _ = battle.performNextAction()
        _ = battle.performNextAction()

        XCTAssertEqual(battle.heroHealth, 9)
        XCTAssertEqual(battle.petHealth, 10)
        XCTAssertEqual(battle.enemyAttackTarget.id, hero.id)
    }

    func testEnemyTargetsHighestHPPartyMember() {
        let hero = Combatant(id: "h1", name: "Hero", role: .hero, maxHealth: 10, abilities: [])
        let pet = Combatant(id: "p1", name: "Pet", role: .pet, maxHealth: 6, abilities: [])
        let enemy = Combatant(id: "e1", name: "Enemy", role: .enemy, maxHealth: 5, abilities: [.slash])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        XCTAssertEqual(battle.enemyAttackTarget.id, hero.id)
        _ = battle.performNextAction()
        _ = battle.performNextAction()
        _ = battle.performNextAction()

        XCTAssertEqual(battle.heroHealth, 9)
        XCTAssertEqual(battle.petHealth, 6)
    }

    func testBattleContinuesWhileAnyPartyMemberLives() {
        let hero = Combatant(id: "h1", name: "Hero", role: .hero, maxHealth: 3, abilities: [])
        let pet = Combatant(id: "p1", name: "Pet", role: .pet, maxHealth: 3, abilities: [])
        let enemy = Combatant(id: "e1", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        while !battle.isPartyDefeated {
            _ = battle.performNextAction()
        }

        XCTAssertTrue(battle.isPartyDefeated)
        XCTAssertTrue(battle.isBattleOver)
        XCTAssertEqual(battle.heroHealth, 0)
        XCTAssertEqual(battle.petHealth, 0)
        let defeatLog = battle.log.last { $0.text.contains("defeated by") }
        XCTAssertNotNil(defeatLog)
    }

    func testBattleSimulatorReportsDefeatOutcome() {
        let hero = Combatant(id: "h1", name: "Hero", role: .hero, maxHealth: 2, abilities: [])
        let pet = Combatant(id: "p1", name: "Pet", role: .pet, maxHealth: 2, abilities: [])
        let enemy = Combatant(id: "e1", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        let result = BattleSimulator.run(hero: hero, pet: pet, enemy: enemy, maxTicks: 100)

        XCTAssertEqual(result.outcome, .defeat)
        XCTAssertFalse(result.didWin)
        XCTAssertFalse(result.didHitTickLimit)
        XCTAssertEqual(result.finalHeroHealth, 0)
        XCTAssertEqual(result.finalPetHealth, 0)
    }

    func testEnemyAppliesStatusToTargetedPartyMember() {
        let hero = Combatant(id: "h1", name: "Hero", role: .hero, maxHealth: 20, abilities: [])
        let pet = Combatant(id: "p1", name: "Pet", role: .pet, maxHealth: 20, abilities: [])
        let enemy = Combatant(id: "e1", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.kindling])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        while battle.tickCount < 5 {
            _ = battle.performNextAction()
        }

        XCTAssertFalse(battle.heroStatusSummaries.isEmpty || battle.petStatusSummaries.isEmpty,
                        "Enemy should have applied a status to the targeted party member")
    }

    func testPartyStatusKillsMember() {
        let hero = Combatant(id: "h1", name: "Hero", role: .hero, maxHealth: 10, abilities: [])
        let pet = Combatant(id: "p1", name: "Pet", role: .pet, maxHealth: 3, abilities: [])
        let enemy = Combatant(id: "e1", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleState(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activePetStatuses: [ActiveStatus(id: 1, keyword: .burn, remainingTicks: 5, tickDamage: 10)]
        )

        while !battle.isBattleOver {
            _ = battle.performNextAction()
        }

        XCTAssertEqual(battle.petHealth, 0)
    }

    func testEnemyUsesBasicSkillAndUltimateCadence() {
        let hero = Combatant(id: "h1", name: "Hero", role: .hero, maxHealth: 100, abilities: [])
        let pet = Combatant(id: "p1", name: "Pet", role: .pet, maxHealth: 100, abilities: [])
        let enemy = Combatant(id: "e1", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash, .smite, .blessedAegis])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        while battle.enemyActionCount < 6 {
            _ = battle.performNextAction()
        }

        let enemyAbilities = battle.log.filter { $0.text.contains("Enemy uses") }
        XCTAssertGreaterThanOrEqual(enemyAbilities.count, 2)
        XCTAssertEqual(battle.enemyActionCount, 6)
    }

    func testBattleSimulatorHandlesEmptyBatchRuns() {
        let matchup = BattleMatchup(
            hero: GameContent.heroes[0],
            pet: wolfPet,
            enemy: defaultTestEnemy
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
