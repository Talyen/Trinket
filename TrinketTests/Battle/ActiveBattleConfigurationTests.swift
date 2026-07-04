import XCTest
@testable import Trinket

final class ActiveBattleConfigurationTests: XCTestCase {
    func testMakeWithoutEquipmentUsesZeroModifiers() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let enemy = try XCTUnwrap(GameContent.enemies.first?.combatant)

        let configuration = ActiveBattleConfiguration.make(
            hero: knight,
            pet: wolf,
            enemy: enemy
        )

        XCTAssertEqual(configuration.heroModifiers, .zero)
        XCTAssertEqual(configuration.petModifiers, .zero)
        XCTAssertEqual(configuration.hero.id, knight.id)
        XCTAssertEqual(configuration.pet.id, wolf.id)
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
        var loadout = EquipmentLoadout()
        loadout.equip(item)
        let inventory = PlayerInventoryState(items: [item])

        let configuration = ActiveBattleConfiguration.make(
            hero: knight,
            pet: wolf,
            enemy: enemy,
            heroEquipmentLoadout: loadout,
            inventoryState: inventory
        )

        XCTAssertEqual(configuration.heroModifiers.damageDealtBonus(for: .physical), 1)
        XCTAssertEqual(configuration.hero.primaryStats.strength, knight.primaryStats.strength)
    }

    func testMakeResolvesEnemyTraitModifiers() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let wolf = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let skeleton = try XCTUnwrap(GameContent.enemy(matching: "skeleton"))

        let configuration = ActiveBattleConfiguration.make(
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

        let configuration = ActiveBattleConfiguration.make(
            stageID: stage.id,
            hero: knight,
            pet: wolf,
            enemy: enemy,
            stageReward: stage.rewards,
            rewardItemNames: ["Shortsword"]
        )

        XCTAssertEqual(configuration.stageID, stage.id)
        XCTAssertEqual(configuration.stageReward, stage.rewards)
        XCTAssertEqual(configuration.rewardItemNames, ["Shortsword"])
    }
}
