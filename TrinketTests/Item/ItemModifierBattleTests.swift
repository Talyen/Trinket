import XCTest
@testable import Trinket

final class ItemModifierBattleTests: XCTestCase {
    func testEquippedPhysicalDamageAffixIncreasesDirectDamage() throws {
        let keen = try XCTUnwrap(GameContent.itemAffixDefinitions.first { $0.id == "keen" })
        let modifiers = CombatModifierProfile(modifiers: keen.basic.modifiers)

        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.slash]
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: []
        )

        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            heroModifiers: modifiers
        )

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        XCTAssertEqual(100 - battle.enemyHealth, 2)
    }

    func testEquippedMaximumHealthAffixIncreasesStartingHealth() throws {
        let hale = try XCTUnwrap(GameContent.itemAffixDefinitions.first { $0.id == "hale" })
        let modifiers = CombatModifierProfile(modifiers: hale.basic.modifiers)

        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            actionIntervalTicks: 100,
            abilities: [],
            primaryStats: PrimaryStats(toughness: 0)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 10, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 10,
            actionIntervalTicks: 100,
            abilities: []
        )

        let battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            heroModifiers: modifiers
        )

        XCTAssertEqual(battle.heroHealth, 14)
    }

    func testEquippedMightyAffixIncreasesStrengthBasedDamage() throws {
        let mighty = try XCTUnwrap(GameContent.itemAffixDefinitions.first { $0.id == "mighty" })
        let baseType = try XCTUnwrap(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let item = InventoryItem(
            id: "mighty-longsword",
            baseType: baseType,
            rarity: .basic,
            displayName: baseType.name,
            affixes: [mighty.resolved(for: .basic)]
        )
        var loadout = EquipmentLoadout()
        loadout.equip(item)
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.slash],
            primaryStats: PrimaryStats(strength: 4)
        )
        let configuration = ActiveBattleConfiguration.make(
            hero: hero,
            pet: Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, actionIntervalTicks: 100, abilities: []),
            enemy: Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100, abilities: []),
            heroEquipmentLoadout: loadout,
            inventoryState: PlayerInventoryState(items: [item])
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: configuration.hero,
            pet: configuration.pet,
            enemy: configuration.enemy,
            heroModifiers: configuration.heroModifiers
        )

        _ = battle.advanceOneStep()
        _ = battle.advanceOneStep()

        XCTAssertEqual(100 - battle.enemyHealth, 2)
    }

    func testEquippedSerratedAffixIncreasesBleedDamage() throws {
        let serrated = try XCTUnwrap(GameContent.itemAffixDefinitions.first { $0.id == "serrated" })
        let modifiers = CombatModifierProfile(modifiers: serrated.basic.modifiers)
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            actionIntervalTicks: 1,
            abilities: [.fangs]
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, actionIntervalTicks: 100, abilities: [])
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 100,
            abilities: []
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            heroModifiers: modifiers
        )

        _ = battle.advanceOneStep()

        XCTAssertEqual(100 - battle.enemyHealth, 2)
    }
}
