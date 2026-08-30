import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct CombatBuildResolverTests {
    @Test func `equipped damage affixes aggregate into modifier profile`() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let keen = try #require(GameContent.itemAffixDefinitions.first { $0.id == "keen" })
        let serrated = try #require(GameContent.itemAffixDefinitions.first { $0.id == "serrated" })

        let item = InventoryItem(
            id: "keen-serrated-longsword",
            baseType: baseType,
            rarity: .astral,
            displayName: baseType.name,
            affixes: [keen.resolved(for: .astral), serrated.resolved(for: .astral)],
        )

        var loadout = EquipmentLoadout()
        loadout.equip(item, inventory: [item])

        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: loadout,
            inventory: [item],
        )

        try #expect(build.modifiers.damageDealtBonus[.physical] == 3)
        try #expect(build.modifiers.damageDealtBonus[.bleed] == 2)
    }

    @Test func `multiple equipped items stack modifiers`() throws {
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
            affixes: [],
        )
        let armor = InventoryItem(
            id: "armor",
            baseType: armorType,
            rarity: .basic,
            displayName: armorType.name,
            affixes: [hale.resolved(for: .basic), bulwark.resolved(for: .basic)],
        )

        var loadout = EquipmentLoadout()
        loadout.equip(weapon, inventory: [weapon, armor])
        loadout.equip(armor, inventory: [weapon, armor])

        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: loadout,
            inventory: [weapon, armor],
        )

        try #expect(build.modifiers.maximumHealthBonus == 6)
        try #expect(build.modifiers.blockGainedBonus == 2)
        try #expect(build.effectiveMaxHealth == knight.maxHealth + 6)
    }

    @Test func `enemy traits merge into enemy build profile`() throws {
        let livingArmor = try #require(GameContent.enemies.first { $0.id == "living_armor" })
        let build = CombatBuildResolver.build(enemy: livingArmor)

        try #expect(build.modifiers.damageTakenReduction[.bleed] == 0.30)
        try #expect(build.modifiers.triggers.blockPerTurn == 1)
        try #expect(build.modifiers.traitDisplayName == "Living Armor")
    }

    @Test func `corrupted instance powers override catalog values`() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "greatsword" })
        let keen = try #require(GameContent.itemAffixDefinitions.first { $0.id == "keen" })
        let overridden = ItemAffixPower(
            description: "Increase Physical damage by 9.",
            modifiers: [.damageDealt(.physical, 9)],
        )
        let item = InventoryItem(
            id: "corrupted-greatsword",
            baseType: baseType,
            rarity: .basic,
            displayName: baseType.name,
            affixes: [keen.resolved(for: .basic)],
            isCorrupted: true,
            affixPowers: [overridden],
        )

        var loadout = EquipmentLoadout()
        loadout.equip(item, inventory: [item])
        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: loadout,
            inventory: [item],
        )
        try #expect(build.modifiers.damageDealtBonus[.physical] == 18)
    }

    @Test func `enemy effective stats include profile stat bonuses`() throws {
        let baseCombatant = Combatant(
            id: "test-enemy",
            name: "Test Enemy",
            role: .enemy,
            maxHealth: 50,
            abilities: [],
            primaryStats: PrimaryStats(strength: 10, agility: 12, toughness: 8, intellect: 5, wisdom: 6),
        )
        let enemy = Enemy(
            combatant: baseCombatant,
            traitID: "",
            isBoss: false,
        )
        let build = CombatBuildResolver.build(enemy: enemy)
        try #expect(build.combatant.primaryStats == baseCombatant.primaryStats)
    }

    @Test func `equipped affix writes trigger ability name from title`() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let payday = try #require(GameContent.itemAffixDefinitions.first { $0.id == "payday" })
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.slot == .accessory })
        let item = InventoryItem(
            id: "payday-ring",
            baseType: baseType,
            rarity: .basic,
            displayName: baseType.name,
            affixes: [payday.resolved(for: .basic)],
        )
        var loadout = EquipmentLoadout()
        loadout.equip(item, inventory: [item])
        let build = CombatBuildResolver.build(
            combatant: knight,
            equipmentLoadout: loadout,
            inventory: [item],
        )
        try #expect(build.modifiers.triggerAbilityName("dodgeGoldFlat", fallback: "") == "Payday")
    }

    @Test func `equipped affix title wins shared trigger field over talent`() throws {
        let fox = try #require(GameContent.companions.first { $0.id == "fox" })
        let payday = try #require(GameContent.itemAffixDefinitions.first { $0.id == "payday" })
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.slot == .accessory })
        let item = InventoryItem(
            id: "payday-charm",
            baseType: baseType,
            rarity: .basic,
            displayName: baseType.name,
            affixes: [payday.resolved(for: .basic)],
        )
        var loadout = EquipmentLoadout()
        loadout.equip(item, inventory: [item])
        let build = CombatBuildResolver.build(
            combatant: fox,
            equipmentLoadout: loadout,
            inventory: [item],
            unlockedTalents: ["fox_gold_t1_1"],
        )
        try #expect(build.modifiers.triggerAbilityName("dodgeGoldFlat", fallback: "") == "Payday")
        try #expect(build.modifiers.triggers.dodgeGoldFlat == 3)
    }
}
