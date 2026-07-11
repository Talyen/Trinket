import Testing
import TrinketContent

struct EnemyCatalogTests {
    private static let bossIDs: Set<String> = [
        "the_blight_treant",
        "the_forge_golem",
        "the_frostwarden",
        "the_iron_bear"
    ]

    private static let bossBaseHealth: Set<Int> = [24, 26, 27, 28]

    private static let eliteIDs: Set<String> = [
        "living_armor",
        "mimic",
        "necromancer",
        "plague_doctor"
    ]

    @Test func enemyCount() throws {
        try #expect(GameContent.enemies.count == 15)
    }

    @Test(arguments: GameContent.enemies)
    func bossClassification(enemy: Enemy) throws {
        if Self.bossIDs.contains(enemy.id) {
            try #expect(enemy.isBoss, "\(enemy.name) should be a boss")
            try #expect(!enemy.isElite, "\(enemy.name) should not also be elite")
        } else {
            try #expect(!enemy.isBoss, "\(enemy.name) should not be a boss")
        }
    }

    @Test(arguments: GameContent.enemies)
    func eliteClassification(enemy: Enemy) throws {
        if Self.eliteIDs.contains(enemy.id) {
            try #expect(enemy.isElite, "\(enemy.name) should be elite")
            try #expect(!enemy.isBoss, "\(enemy.name) should not be a boss")
        } else if !Self.bossIDs.contains(enemy.id) {
            try #expect(!enemy.isElite, "\(enemy.name) should not be elite")
        }
    }

    @Test func mimicUsesPhysicalAssassinKitWithoutPoison() throws {
        let mimic = try #require(GameContent.enemies.first { $0.id == "mimic" })
        let loadout = mimic.combatant.abilityLoadout
        try #expect(loadout.basic == .stab)
        try #expect(loadout.skill == .serratedEdge)
        try #expect(loadout.ultimate == .hemorrhage)
    }

    @Test func ironBearUsesBashAndMoltenBulwark() throws {
        let bear = try #require(GameContent.enemies.first { $0.id == "the_iron_bear" })
        let loadout = bear.combatant.abilityLoadout
        try #expect(loadout.basic == .bash)
        try #expect(loadout.ultimate == .moltenBulwark)
    }

    @Test func blightTreantUsesFangs() throws {
        let treant = try #require(GameContent.enemies.first { $0.id == "the_blight_treant" })
        try #expect(treant.combatant.abilityLoadout.basic == .fangs)
    }

    @Test(arguments: GameContent.enemies)
    func eachEnemyHasAuthoredBaseHealth(enemy: Enemy) throws {
        if enemy.isBoss {
            try #expect(
                Self.bossBaseHealth.contains(enemy.maxHealth),
                "\(enemy.name) should use a boss base HP band"
            )
        } else if enemy.isElite {
            try #expect(enemy.maxHealth >= 12, "\(enemy.name) should have elite base HP")
            try #expect(enemy.maxHealth <= 15, "\(enemy.name) should have elite base HP")
        } else {
            try #expect(enemy.maxHealth >= 11, "\(enemy.name) should have fodder base HP")
            try #expect(enemy.maxHealth <= 15, "\(enemy.name) should have fodder base HP")
        }
    }

    @Test(arguments: GameContent.enemies)
    func eachEnemyHasGrowthArchetype(enemy: Enemy) throws {
        try #expect(!enemy.combatant.growthArchetype.rawValue.isEmpty)
    }

    @Test func idsAreUniqueAcrossCombatants() throws {
        let allIDs = Set(GameContent.heroes.map(\.id))
            .union(GameContent.pets.map(\.id))
            .union(GameContent.enemies.map(\.id))
        let combinedCount = GameContent.heroes.count + GameContent.pets.count + GameContent.enemies.count
        try #expect(allIDs.count == combinedCount, "Hero, pet, and enemy IDs must be globally unique")
    }

    @Test(arguments: GameContent.enemies)
    func eachEnemyHasBasicSkillUltimate(enemy: Enemy) throws {
        let loadout = enemy.combatant.abilityLoadout
        try #require(loadout.basic != nil, "\(enemy.name) should have a basic ability")
        try #require(loadout.skill != nil, "\(enemy.name) should have a skill ability")
        try #require(loadout.ultimate != nil, "\(enemy.name) should have an ultimate ability")
    }

    @Test func averagePlayerBaseHealthExceedsFodderEnemyBaseHealth() throws {
        let heroAverage = Double(GameContent.heroes.map(\.maxHealth).reduce(0, +)) / Double(GameContent.heroes.count)
        let petAverage = Double(GameContent.pets.map(\.maxHealth).reduce(0, +)) / Double(GameContent.pets.count)
        let enemyAverage = Double(
            GameContent.enemies.filter { !$0.isBoss }.map(\.maxHealth).reduce(0, +)
        ) / Double(GameContent.enemies.filter { !$0.isBoss }.count)

        try #expect(heroAverage > enemyAverage)
        try #expect(petAverage > enemyAverage)
    }
}
