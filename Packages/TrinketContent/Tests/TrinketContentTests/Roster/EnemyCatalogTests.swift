import Testing
import TrinketContent
import TrinketCore

struct EnemyCatalogTests {
    @Test func `enemy catalog invariants`() throws {
        for enemy in GameContent.enemies {
            if !enemy.isBoss {
                #expect((11 ... 15).contains(enemy.maxHealth), "\(enemy.name) should have normal base HP")
            }
            let loadout = enemy.combatant.abilityLoadout
            for tier in AbilityTier.allCases {
                let ability = try #require(loadout.ability(for: tier), "\(enemy.name) needs a \(tier.rawValue) ability")
                #expect(ability.tier == tier, "\(enemy.name) has the wrong tier in its \(tier.rawValue) slot")
                #expect(AbilityCatalog.ability(id: ability.id) == ability, "\(enemy.name) has a stale or unknown ability \(ability.id)")
            }
            try #expect(!enemy.combatant.hasMana, "\(enemy.name) should not have Mana")
        }
    }

    @Test func `ids are unique across combatants`() throws {
        let allIDs = Set(GameContent.heroes.map(\.id))
            .union(GameContent.companions.map(\.id))
            .union(GameContent.enemies.map(\.id))
        let combinedCount = GameContent.heroes.count + GameContent.companions.count + GameContent.enemies.count
        try #expect(allIDs.count == combinedCount, "Hero, companion, and enemy IDs must be globally unique")
    }
}
