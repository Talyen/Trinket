import TrinketContent
import TrinketPersistence
import XCTest
@testable import Trinket

@MainActor
final class ActiveBattleConfigurationTests: XCTestCase {
    func testMakeWithoutEquipmentUsesTraitOnlyModifiers() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let enemy = try XCTUnwrap(GameContent.enemies.first?.combatant)

        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: knight,
            pet: wolf,
            enemy: enemy
        )

        XCTAssertEqual(configuration.hero.modifiers.blockGainedBonus, 1)
        XCTAssertEqual(configuration.pet.modifiers.bleedDurationBonus, 1)
        XCTAssertEqual(configuration.hero.modifiers.damageDealtBonus(for: .physical), 0)
        XCTAssertEqual(configuration.pet.modifiers.damageDealtBonus(for: .physical), 0)
        XCTAssertEqual(configuration.hero.combatant.id, knight.id)
        XCTAssertEqual(configuration.pet.combatant.id, wolf.id)
    }

    func testMakeResolvesEquippedItemModifiers() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let enemy = try XCTUnwrap(GameContent.enemies.first?.combatant)
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let keen = try XCTUnwrap(GameContent.itemAffixDefinitions.first { $0.id == "keen" })
        let item = InventoryItem(
            id: "keen-longsword",
            baseType: baseType,
            rarity: .basic,
            displayName: baseType.name,
            affixes: [keen.resolved(for: .basic)]
        )
        var rosterState = PlayerRosterState.initial
        var loadout = EquipmentLoadout()
        loadout.equip(item)
        rosterState.setEquipmentLoadout(loadout, for: knight)

        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: knight,
            pet: wolf,
            enemy: enemy,
            roster: rosterState,
            inventory: PlayerInventoryState(items: [item])
        )

        XCTAssertEqual(configuration.hero.modifiers.damageDealtBonus(for: .physical), 1)
        XCTAssertEqual(configuration.hero.combatant.primaryStats.strength, knight.primaryStats.strength)
    }

    func testMakeResolvesEnemyTraitModifiers() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let skeleton = try XCTUnwrap(GameContent.enemy(matching: "skeleton"))

        let configuration = ActiveBattleConfigurationTestSupport.make(
            rngSeed: 0,
            hero: knight,
            pet: wolf,
            enemy: skeleton.combatant
        )

        XCTAssertGreaterThan(configuration.enemyModifiers.damageTakenVulnerability(for: .holy), 0)
        XCTAssertGreaterThan(configuration.enemyModifiers.controlResistancePercent, 0)
    }

    func testMakePreservesStageMetadata() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        let enemy = try XCTUnwrap(try GameContent.enemy(matching: XCTUnwrap(stage.encounter.battleEnemyID))?.combatant)
        let expectedItemName = try XCTUnwrap(
            GameContent.itemTemplate(matching: XCTUnwrap(stage.rewards.itemTemplateIDs.first))?.displayName
        )

        let configuration = ActiveBattleConfigurationTestSupport.make(
            stageID: stage.id,
            rngSeed: 0,
            hero: knight,
            pet: wolf,
            enemy: enemy,
            stageReward: stage.rewards
        )

        XCTAssertEqual(configuration.stageID, stage.id)
        XCTAssertEqual(configuration.stageReward, stage.rewards)
        XCTAssertEqual(configuration.rewardItemNames, [expectedItemName])
    }

    func testResolvedEncounterScalesEnemyToJourneyLevel() throws {
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        let encounter = try XCTUnwrap(ActiveBattleConfiguration.resolvedEncounter(for: stage))
        let chapter = try XCTUnwrap(GameContent.chapters.first { $0.id == stage.chapterID })
        let expectedLevel = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)

        XCTAssertEqual(encounter.level, expectedLevel)
        XCTAssertEqual(encounter.combatant.id, stage.encounter.battleEnemyID)
    }
}
