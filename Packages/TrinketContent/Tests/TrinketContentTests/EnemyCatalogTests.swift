import Testing
import TrinketContent

@Suite struct EnemyCatalogTests {
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

    @Test func enemyCount() {
        #expect(GameContent.enemies.count == 15)
    }

    @Test(arguments: GameContent.enemies)
    func bossClassification(enemy: Enemy) {
        if Self.bossIDs.contains(enemy.id) {
            #expect(enemy.isBoss, "\(enemy.name) should be a boss")
            #expect(!enemy.isElite, "\(enemy.name) should not also be elite")
        } else {
            #expect(!enemy.isBoss, "\(enemy.name) should not be a boss")
        }
    }

    @Test(arguments: GameContent.enemies)
    func eliteClassification(enemy: Enemy) {
        if Self.eliteIDs.contains(enemy.id) {
            #expect(enemy.isElite, "\(enemy.name) should be elite")
            #expect(!enemy.isBoss, "\(enemy.name) should not be a boss")
        } else if !Self.bossIDs.contains(enemy.id) {
            #expect(!enemy.isElite, "\(enemy.name) should not be elite")
        }
    }

    @Test func mimicUsesPhysicalAssassinKitWithoutPoison() {
        let mimic = #require(GameContent.enemies.first { $0.id == "mimic" })
        let loadout = mimic.combatant.abilityLoadout
        #expect(loadout.basic == .stab)
        #expect(loadout.skill == .serratedEdge)
        #expect(loadout.ultimate == .hemorrhage)
    }

    @Test func ironBearUsesBashAndMoltenBulwark() {
        let bear = #require(GameContent.enemies.first { $0.id == "the_iron_bear" })
        let loadout = bear.combatant.abilityLoadout
        #expect(loadout.basic == .bash)
        #expect(loadout.ultimate == .moltenBulwark)
    }

    @Test func blightTreantUsesFangs() {
        let treant = #require(GameContent.enemies.first { $0.id == "the_blight_treant" })
        #expect(treant.combatant.abilityLoadout.basic == .fangs)
    }

    @Test(arguments: GameContent.enemies)
    func eachEnemyHasAuthoredBaseHealth(enemy: Enemy) {
        if enemy.isBoss {
            #expect(
                Self.bossBaseHealth.contains(enemy.maxHealth),
                "\(enemy.name) should use a boss base HP band"
            )
        } else if enemy.isElite {
            #expect(enemy.maxHealth >= 12, "\(enemy.name) should have elite base HP")
            #expect(enemy.maxHealth <= 15, "\(enemy.name) should have elite base HP")
        } else {
            #expect(enemy.maxHealth >= 11, "\(enemy.name) should have fodder base HP")
            #expect(enemy.maxHealth <= 15, "\(enemy.name) should have fodder base HP")
        }
    }

    @Test(arguments: GameContent.enemies)
    func eachEnemyHasGrowthArchetype(enemy: Enemy) {
        #expect(!enemy.combatant.growthArchetype.rawValue.isEmpty)
    }

    @Test func idsAreUniqueAcrossCombatants() {
        let allIDs = Set(GameContent.heroes.map(\.id))
            .union(GameContent.pets.map(\.id))
            .union(GameContent.enemies.map(\.id))
        let combinedCount = GameContent.heroes.count + GameContent.pets.count + GameContent.enemies.count
        #expect(allIDs.count == combinedCount, "Hero, pet, and enemy IDs must be globally unique")
    }

    @Test func averagePlayerBaseHealthExceedsFodderEnemyBaseHealth() {
        let heroAverage = Double(GameContent.heroes.map(\.maxHealth).reduce(0, +)) / Double(GameContent.heroes.count)
        let petAverage = Double(GameContent.pets.map(\.maxHealth).reduce(0, +)) / Double(GameContent.pets.count)
        let enemyAverage = Double(
            GameContent.enemies.filter { !$0.isBoss }.map(\.maxHealth).reduce(0, +)
        ) / Double(GameContent.enemies.filter { !$0.isBoss }.count)

        #expect(heroAverage > enemyAverage)
        #expect(petAverage > enemyAverage)
    }
}
