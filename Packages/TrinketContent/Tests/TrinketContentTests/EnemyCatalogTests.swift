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
            try #expect(!enemy.combatant.growthArchetype.rawValue.isEmpty)
            try #expect(!enemy.combatant.hasMana, "\(enemy.name) should not have Mana")
            let loadout = enemy.combatant.abilityLoadout
            try #require(loadout.basic != nil, "\(enemy.name) should have a basic ability")
            try #require(loadout.skill != nil, "\(enemy.name) should have a skill ability")
            try #require(loadout.ultimate != nil, "\(enemy.name) should have an ultimate ability")
            try #expect(
                enemy.combatant.primaryStats == enemy.combatant.growthArchetype.identityPrimaryStats,
                "\(enemy.name) should use its archetype identity stats",
            )
        }
    }

    @Test func `special enemy loadouts match their archetypes`() throws {
        let mimic = try #require(GameContent.enemies.first { $0.id == "mimic" })
        try #expect(mimic.combatant.abilityLoadout.basic == .fangs)
        try #expect(mimic.combatant.abilityLoadout.skill == .acidPotion)
        try #expect(mimic.combatant.abilityLoadout.ultimate == .hemorrhage)

        let bear = try #require(GameContent.enemies.first { $0.id == "the_iron_bear" })
        try #expect(bear.combatant.abilityLoadout.basic == .bash)
        try #expect(bear.combatant.abilityLoadout.skill == .sunder)
        try #expect(bear.combatant.abilityLoadout.ultimate == .thornMail)

        let treant = try #require(GameContent.enemies.first { $0.id == "the_blight_treant" })
        try #expect(treant.combatant.abilityLoadout.basic == .causticJab)

        let frostwarden = try #require(GameContent.enemies.first { $0.id == "the_frostwarden" })
        try #expect(frostwarden.combatant.abilityLoadout.basic == .rayOfFrost)
        try #expect(frostwarden.combatant.abilityLoadout.skill == .glacialWard)
        try #expect(frostwarden.combatant.abilityLoadout.ultimate == .blizzard)

        let livingArmor = try #require(GameContent.enemies.first { $0.id == "living_armor" })
        try #expect(livingArmor.combatant.abilityLoadout.ultimate == .thornMail)
    }

    @Test func `ids are unique across combatants`() throws {
        let allIDs = Set(GameContent.heroes.map(\.id))
            .union(GameContent.companions.map(\.id))
            .union(GameContent.enemies.map(\.id))
        let combinedCount = GameContent.heroes.count + GameContent.companions.count + GameContent.enemies.count
        try #expect(allIDs.count == combinedCount, "Hero, companion, and enemy IDs must be globally unique")
    }

    @Test func `average player base health exceeds normal enemy base health`() throws {
        let heroAverage = Double(GameContent.heroes.map(\.maxHealth).reduce(0, +)) / Double(GameContent.heroes.count)
        let companionAverage = Double(GameContent.companions.map(\.maxHealth).reduce(0, +)) / Double(GameContent.companions.count)
        let enemyAverage = Double(
            GameContent.enemies.filter { !$0.isBoss }.map(\.maxHealth).reduce(0, +),
        ) / Double(GameContent.enemies.count(where: { !$0.isBoss }))

        try #expect(heroAverage > enemyAverage)
        try #expect(companionAverage > enemyAverage)
    }

    @Test func `authored factions match encounter fantasy`() throws {
        let skeleton = try #require(GameContent.enemy(matching: "skeleton"))
        let necromancer = try #require(GameContent.enemy(matching: "necromancer"))
        let treant = try #require(GameContent.enemy(matching: "the_blight_treant"))
        let golem = try #require(GameContent.enemy(matching: "the_forge_golem"))
        try #expect(skeleton.faction == .undead)
        try #expect(necromancer.faction == .undead)
        try #expect(treant.faction == .corrupted)
        try #expect(golem.faction == .construct)
    }

    @Test func `enemy matching lookup returns expected enemy`() throws {
        for enemy in GameContent.enemies {
            let found = try #require(GameContent.enemy(matching: enemy.id))
            try #expect(found.id == enemy.id)
            try #expect(found.name == enemy.name)
            try #expect(found.isBoss == enemy.isBoss)
        }
        try #expect(GameContent.enemy(matching: "non_existent_enemy") == nil)
    }
}
