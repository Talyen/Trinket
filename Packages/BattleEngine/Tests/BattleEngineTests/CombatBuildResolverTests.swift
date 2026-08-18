import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct CombatBuildResolverTests {
    @Test func equippedDamageAffixesAggregateIntoModifierProfile() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let keen = try #require(GameContent.itemAffixDefinitions.first { $0.id == "keen" })
        let serrated = try #require(GameContent.itemAffixDefinitions.first { $0.id == "serrated" })

        let item = InventoryItem(
            id: "keen-serrated-longsword",
            baseType: baseType,
            rarity: .astral,
            displayName: baseType.name,
            affixes: [keen.resolved(for: .astral), serrated.resolved(for: .astral)]
        )

        var loadout = EquipmentLoadout()
        loadout.equip(item, inventory: [item])

        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: loadout,
            inventory: [item]
        )

        try #expect(build.modifiers.damageDealtBonus[.physical] == 3)
        try #expect(build.modifiers.damageDealtBonus[.bleed] == 2)
    }

    @Test func multipleEquippedItemsStackModifiers() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let weaponType = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let armorType = try #require(GameContent.itemBaseTypes.first { $0.id == "plate_armor" })
        let hale = try #require(GameContent.itemAffixDefinitions.first { $0.id == "hale" })
        let bulwark = try #require(GameContent.itemAffixDefinitions.first { $0.id == "bulwark" })

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
        loadout.equip(weapon, inventory: [weapon, armor])
        loadout.equip(armor, inventory: [weapon, armor])

        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: loadout,
            inventory: [weapon, armor]
        )

        try #expect(build.modifiers.maximumHealthBonus == 6)
        try #expect(build.modifiers.blockGainedBonus == 2)
        try #expect(build.effectiveMaxHealth == knight.maxHealth + 6)
    }

    @Test func enemyTraitsMergeIntoEnemyBuildProfile() throws {
        let livingArmor = try #require(GameContent.enemies.first { $0.id == "living_armor" })
        let build = CombatBuildResolver.build(enemy: livingArmor)

        try #expect(build.modifiers.damageTakenReduction[.bleed] == 0.30)
        try #expect(build.modifiers.triggers.blockPerTurn == 1)
        try #expect(build.modifiers.traitDisplayName == "Living Armor")
    }

    @Test func corruptedInstancePowersOverrideCatalogValues() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "greatsword" })
        let keen = try #require(GameContent.itemAffixDefinitions.first { $0.id == "keen" })
        let overridden = ItemAffixPower(
            description: "Increase Physical damage by 9.",
            modifiers: [.damageDealt(.physical, 9)]
        )
        let item = InventoryItem(
            id: "corrupted-greatsword",
            baseType: baseType,
            rarity: .basic,
            displayName: baseType.name,
            affixes: [keen.resolved(for: .basic)],
            isCorrupted: true,
            affixPowers: [overridden]
        )

        var loadout = EquipmentLoadout()
        loadout.equip(item, inventory: [item])
        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: loadout,
            inventory: [item]
        )
        try #expect(build.modifiers.damageDealtBonus[.physical] == 18)
    }
}
