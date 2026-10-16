import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

struct CombatBuildResolverTests {
    @Test(arguments: [41, 60, 100, 250, 1000], [false, true])
    func `enemy build keeps growing past forty`(level: Int, isBoss: Bool) throws {
        let enemy = try #require(GameContent.enemies.first { $0.isBoss == isBoss })
        let previous = CombatBuildResolver.build(enemy: enemy, level: level - 1)
        let current = CombatBuildResolver.build(enemy: enemy, level: level)
        let atForty = CombatBuildResolver.build(enemy: enemy, level: 40)
        #expect(current.combatant.maxHealth >= previous.combatant.maxHealth)
        #expect(current.combatant.maxHealth > atForty.combatant.maxHealth)
        #expect(current.modifiers.outgoingDamagePercent > previous.modifiers.outgoingDamagePercent)
        #expect(current.combatant.abilityChoices == enemy.combatant.abilityChoices)
    }

    @Test(arguments: [false, true])
    func `saved equipment powers saturate within and across items`(combineInOnePower: Bool) throws {
        let affix = ItemAffix(id: "saved-power", title: "Saved Power", description: "", keywords: [])
        let largeModifiers: [AffixModifier] = [
            .maximumHealth(.max), .damageDealt(.physical, .max), .damageTakenFlat(.physical, .max),
            .startBattleBlock(.max), .attackBlockRemoval(.max), .attackPurgeCount(.max),
        ]
        let extraModifiers: [AffixModifier] = [
            .maximumHealth(1), .damageDealt(.physical, 1), .damageTakenFlat(.physical, 1),
            .startBattleBlock(1), .attackBlockRemoval(1), .attackPurgeCount(1),
        ]
        let ring = try ItemFixtures.makeBareItem(
            "ruby_ring", affixes: [affix],
            affixPowers: [ItemAffixPower(
                description: "", modifiers: largeModifiers + (combineInOnePower ? extraModifiers : []),
            )],
        )
        let weapon = try ItemFixtures.makeBareItem(
            "longsword", affixes: [affix],
            affixPowers: [ItemAffixPower(description: "", modifiers: combineInOnePower ? [] : extraModifiers)],
        )
        let build = CombatBuildResolver.build(
            combatant: CombatantFixtures.passiveHero(),
            equipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.accessory: ring.id, .weapon: weapon.id]),
            inventory: [ring, weapon],
        )
        #expect(build.modifiers.maximumHealthBonus == .max)
        #expect(build.modifiers.damageDealtBonus[.physical] == .max)
        #expect(build.modifiers.damageTakenFlat[.physical] == .max)
        #expect(build.modifiers.triggers.startBattleBlock == .max)
        #expect(build.modifiers.triggers.attackBlockRemoval == .max)
        #expect(build.modifiers.triggers.attackPurgeCount == .max)
        #expect(build.effectiveMaxHealth == .max)
    }

    @Test func `saved ranged power saturates when combined with physical power`() throws {
        let affix = ItemAffix(id: "saved-power", title: "Saved Power", description: "", keywords: [])
        let weapon = try ItemFixtures.makeBareItem(
            "shortbow", affixes: [affix],
            affixPowers: [ItemAffixPower(description: "", modifiers: [
                .damageDealt(.physical, .max), .rangedDamageDealt(1),
            ])],
        )
        let build = CombatBuildResolver.build(
            combatant: CombatantFixtures.passiveHero(),
            equipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.weapon: weapon.id]),
            inventory: [weapon],
        )
        #expect(build.modifiers.damageDealtBonus[.physical] == .max)
    }

    @Test func `ranged damage dealt bonus requires equipped ranged weapon`() throws {
        let rangedWeapon = try ItemFixtures.makeBareItem("shortbow")
        let meleeWeapon = try ItemFixtures.makeBareItem("longsword")
        let hero = CombatantFixtures.passiveHero()

        let rangedBonus = [AffixModifier.rangedDamageDealt(3)]

        let rangedBuild = CombatBuildResolver.build(
            combatant: hero,
            equipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.weapon: rangedWeapon.id]),
            inventory: [rangedWeapon],
            additionalModifiers: rangedBonus,
        )
        #expect(rangedBuild.modifiers.damageDealtBonus[.physical] == 3)

        let meleeBuild = CombatBuildResolver.build(
            combatant: hero,
            equipmentLoadout: EquipmentLoadout(itemIDsBySlot: [.weapon: meleeWeapon.id]),
            inventory: [meleeWeapon],
            additionalModifiers: rangedBonus,
        )
        #expect(meleeBuild.modifiers.damageDealtBonus[.physical] == nil)
    }
}
