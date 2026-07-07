import BattleEngine
import Foundation
import TrinketContent

struct BalanceSweepTriple: Equatable, Hashable {
    let hero: Combatant
    let pet: Combatant
    let enemy: Enemy

    var heroID: String {
        hero.id
    }

    var petID: String {
        pet.id
    }

    var enemyID: String {
        enemy.id
    }

    var isBoss: Bool {
        enemy.isBoss
    }

    var isElite: Bool {
        enemy.isElite
    }
}

enum BalanceSweepCatalog {
    private static let earlyFodderEnemyIDs: Set<String> = [
        "skeleton",
        "goblin",
        "slime",
        "mud_elemental",
        "fire_elemental",
        "frost_elemental",
        "will_o_wisp"
    ]

    private static let middleEnemyIDs: Set<String> = [
        "skeleton",
        "goblin",
        "slime",
        "mud_elemental",
        "fire_elemental",
        "frost_elemental",
        "will_o_wisp",
        "plague_doctor",
        "living_armor",
        "mimic",
        "necromancer"
    ]

    static func journeyBattleEnemyIDs() -> Set<String> {
        journeyBattleEnemyIDsCache
    }

    private static let journeyBattleEnemyIDsCache: Set<String> = {
        var ids = Set<String>()
        for chapter in GameContent.chapters {
            for stage in chapter.stages {
                if case let .battle(enemyID) = stage.encounter {
                    ids.insert(enemyID)
                }
            }
        }
        return ids
    }()

    static func enemies(
        for tier: SimulationPowerTier,
        stageWeighted: Bool,
        allEnemies: [Enemy] = GameContent.enemies
    ) -> [Enemy] {
        guard stageWeighted else { return allEnemies }

        let allowedIDs: Set<String>
        switch tier {
        case .early:
            allowedIDs = earlyFodderEnemyIDs.union(
                journeyBattleEnemyIDs().filter { earlyFodderEnemyIDs.contains($0) }
            )
        case .middle:
            allowedIDs = middleEnemyIDs.union(journeyBattleEnemyIDs().subtracting(["the_blight_treant"]))
        case .lateGame:
            return allEnemies
        }

        return allEnemies.filter { allowedIDs.contains($0.id) }
    }

    static func triples(
        for tier: SimulationPowerTier,
        stageWeighted: Bool,
        heroes: [Combatant] = GameContent.heroes,
        pets: [Combatant] = GameContent.pets,
        enemies: [Enemy] = GameContent.enemies
    ) -> [BalanceSweepTriple] {
        let tierEnemies = Self.enemies(
            for: tier,
            stageWeighted: stageWeighted,
            allEnemies: enemies
        )
        return heroes.flatMap { hero in
            pets.flatMap { pet in
                tierEnemies.map { enemy in
                    BalanceSweepTriple(hero: hero, pet: pet, enemy: enemy)
                }
            }
        }
    }

    static func allTriples(
        heroes: [Combatant] = GameContent.heroes,
        pets: [Combatant] = GameContent.pets,
        enemies: [Enemy] = GameContent.enemies
    ) -> [BalanceSweepTriple] {
        triples(for: .early, stageWeighted: false, heroes: heroes, pets: pets, enemies: enemies)
    }

    static func representativeHero(
        id: String = BalanceSweepDefaults.representativeHeroID,
        heroes: [Combatant] = GameContent.heroes
    ) -> Combatant? {
        heroes.first { $0.id == id }
    }

    static func representativePet(
        id: String = BalanceSweepDefaults.representativePetID,
        pets: [Combatant] = GameContent.pets
    ) -> Combatant? {
        pets.first { $0.id == id }
    }
}

enum BalanceSweepDefaults {
    static let representativeHeroID = "knight"
    static let representativePetID = "wolf"
    static let runsPerMatchup = 20
    static let loadoutSamplesPerMatchup = 5
    static let baseSeed: UInt64 = 42026
    static let maxTicks = 100
    static let minFightTicks = 10
}
