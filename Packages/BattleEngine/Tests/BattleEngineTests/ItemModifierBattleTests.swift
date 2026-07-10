import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct ItemModifierBattleTests {
    @Test func equippedPhysicalDamageAffixIncreasesDirectDamage() throws {
        let keen = try #require(GameContent.itemAffixDefinitions.first { $0.id == "keen" })
        let modifiers = CombatModifierProfile(modifiers: keen.basic.modifiers)

        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.slash]
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [])
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: []
        )

        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            heroModifiers: modifiers
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(100 - battle.health(of: battle.enemy) == 2)
    }

    @Test func equippedMaximumHealthAffixIncreasesStartingHealth() throws {
        let hale = try #require(GameContent.itemAffixDefinitions.first { $0.id == "hale" })
        let modifiers = CombatModifierProfile(modifiers: hale.basic.modifiers)

        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            abilities: [],
            primaryStats: PrimaryStats(toughness: 0)
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 10, abilities: [])
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 10,
            abilities: []
        )

        let battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            heroModifiers: modifiers
        )

        try #expect(battle.health(of: battle.hero) == 14)
    }

    @Test func equippedMightyAffixIncreasesStrengthBasedDamage() throws {
        let mighty = try #require(GameContent.itemAffixDefinitions.first { $0.id == "mighty" })
        let baseType = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
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
            abilities: [.slash],
            primaryStats: PrimaryStats(strength: 4)
        )
        let configuration = CombatBuildResolver.build(
            combatant: hero,
            equipmentLoadout: loadout,
            inventory: [item]
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: configuration.combatant,
            pet: Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: []),
            enemy: Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: []),
            heroModifiers: configuration.modifiers
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(100 - battle.health(of: battle.enemy) == 2)
    }

    @Test func equippedSerratedAffixIncreasesBleedDamage() throws {
        let serrated = try #require(GameContent.itemAffixDefinitions.first { $0.id == "serrated" })
        let modifiers = CombatModifierProfile(modifiers: serrated.basic.modifiers)
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.fangs]
        )
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [])
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            abilities: []
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            heroModifiers: modifiers
        )

        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle)

        try #expect(100 - battle.health(of: battle.enemy) == 2)
    }
}
