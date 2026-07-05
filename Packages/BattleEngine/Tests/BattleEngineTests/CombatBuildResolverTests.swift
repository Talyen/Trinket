import XCTest
import BattleEngine
import TrinketContent
import TrinketCore

final class CombatBuildResolverTests: XCTestCase {
    func testEquippedStatAffixesMergeIntoEffectiveStats() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let mighty = try XCTUnwrap(GameContent.itemAffixDefinitions.first { $0.id == "mighty" })

        let item = InventoryItem(
            id: "mighty-longsword",
            baseType: baseType,
            rarity: .basic,
            displayName: baseType.name,
            affixes: [mighty.resolved(for: .basic)]
        )

        var loadout = EquipmentLoadout()
        loadout.equip(item)

        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: loadout,
            inventory: [item]
        )

        XCTAssertEqual(build.combatant.primaryStats.strength, knight.primaryStats.strength + 1)
        XCTAssertEqual(build.modifiers.damageDealtBonus(for: .physical), 0)
    }

    func testEquippedDamageAffixesAggregateIntoModifierProfile() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let keen = try XCTUnwrap(GameContent.itemAffixDefinitions.first { $0.id == "keen" })
        let serrated = try XCTUnwrap(GameContent.itemAffixDefinitions.first { $0.id == "serrated" })

        let item = InventoryItem(
            id: "keen-serrated-longsword",
            baseType: baseType,
            rarity: .astral,
            displayName: baseType.name,
            affixes: [keen.resolved(for: .astral), serrated.resolved(for: .astral)]
        )

        var loadout = EquipmentLoadout()
        loadout.equip(item)

        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: loadout,
            inventory: [item]
        )

        XCTAssertEqual(build.modifiers.damageDealtBonus[.physical], 3)
        XCTAssertEqual(build.modifiers.damageDealtBonus[.bleed], 2)
    }

    func testMultipleEquippedItemsStackModifiers() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let weaponType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let armorType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.id == "plate_armor" })
        let hale = try XCTUnwrap(GameContent.itemAffixDefinitions.first { $0.id == "hale" })
        let bulwark = try XCTUnwrap(GameContent.itemAffixDefinitions.first { $0.id == "bulwark" })

        let weapon = InventoryItem(
            id: "weapon",
            baseType: weaponType,
            rarity: .basic,
            displayName: weaponType.name,
            affixes: []
        )
        let armor = InventoryItem(
            id: "armor",
            baseType: armorType,
            rarity: .basic,
            displayName: armorType.name,
            affixes: [hale.resolved(for: .basic), bulwark.resolved(for: .basic)]
        )

        var loadout = EquipmentLoadout()
        loadout.equip(weapon)
        loadout.equip(armor)

        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: loadout,
            inventory: [weapon, armor]
        )

        XCTAssertEqual(build.modifiers.maximumHealthBonus, 4)
        XCTAssertEqual(build.modifiers.blockGainedBonus, 3)
        XCTAssertEqual(build.effectiveMaxHealth, knight.maxHealth + knight.primaryStats.toughness + 4)
    }

    func testTraitModifiersMergeIntoBuildProfile() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )

        XCTAssertEqual(build.modifiers.blockGainedBonus, 1)
        XCTAssertEqual(GameContent.trait(forCombatantID: knight.id)?.name, "Oathbound")
    }
}
