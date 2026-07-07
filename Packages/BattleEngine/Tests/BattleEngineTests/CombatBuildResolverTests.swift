import Testing
import BattleEngine
import TrinketContent
import TrinketCore

@Suite
struct CombatBuildResolverTests {
    @Test func equippedStatAffixesMergeIntoEffectiveStats() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let mighty = try #require(GameContent.itemAffixDefinitions.first { $0.id == "mighty" })

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

        #expect(build.combatant.primaryStats.strength == knight.primaryStats.strength + 1)
        #expect(build.modifiers.damageDealtBonus(for: .physical) == 0)
    }

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
        loadout.equip(item)

        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: loadout,
            inventory: [item]
        )

        #expect(build.modifiers.damageDealtBonus[.physical] == 3)
        #expect(build.modifiers.damageDealtBonus[.bleed] == 2)
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
        loadout.equip(weapon)
        loadout.equip(armor)

        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: loadout,
            inventory: [weapon, armor]
        )

        #expect(build.modifiers.maximumHealthBonus == 4)
        #expect(build.modifiers.blockGainedBonus == 3)
        #expect(build.effectiveMaxHealth == knight.maxHealth + knight.primaryStats.toughness + 4)
    }

    @Test func traitModifiersMergeIntoBuildProfile() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: EquipmentLoadout(),
            inventory: []
        )

        #expect(build.modifiers.blockGainedBonus == 1)
        #expect(build.modifiers.traitDisplayName == "Oathbound")
    }
}
