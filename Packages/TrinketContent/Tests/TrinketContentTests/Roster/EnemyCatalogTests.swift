import Testing
import TrinketContent
import TrinketCore

struct EnemyCatalogTests {
    private static let bossIDs: Set<String> = [
        "the_blight_treant",
        "the_blood_countess",
        "the_forge_golem",
        "the_frostwarden",
        "the_iron_bear",
        "the_seraph",
        "the_stone_titan",
    ]

    @Test func `enemy catalog invariants`() throws {
        for enemy in GameContent.enemies {
            if Self.bossIDs.contains(enemy.id) {
                try #expect(enemy.isBoss, "\(enemy.name) should be a boss")
            } else {
                try #expect(!enemy.isBoss, "\(enemy.name) should not be a boss")
                try #expect(enemy.maxHealth >= 11, "\(enemy.name) should have normal base HP")
                try #expect(enemy.maxHealth <= 15, "\(enemy.name) should have normal base HP")
            }
            try #expect(!enemy.combatant.hasMana, "\(enemy.name) should not have Mana")
            let loadout = enemy.combatant.abilityLoadout
            try #require(loadout.basic != nil, "\(enemy.name) should have a basic ability")
            try #require(loadout.skill != nil, "\(enemy.name) should have a skill ability")
            try #require(loadout.ultimate != nil, "\(enemy.name) should have an ultimate ability")
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
