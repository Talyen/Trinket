import Foundation
import TrinketContent

public struct BalanceSweepTriple: Equatable, Hashable, Sendable {
    public let hero: Combatant
    public let pet: Combatant
    public let enemy: Enemy

    public init(hero: Combatant, pet: Combatant, enemy: Enemy) {
        self.hero = hero
        self.pet = pet
        self.enemy = enemy
    }

    public var heroID: String { hero.id }
    public var petID: String { pet.id }
    public var enemyID: String { enemy.id }
    public var isBoss: Bool { enemy.isBoss }
    public var isElite: Bool { enemy.isElite }
}

public enum BalanceSweepCatalog {
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

    public static func journeyBattleEnemyIDs() -> Set<String> {
        var ids = Set<String>()
        for chapter in GameContent.chapters {
            for stage in chapter.stages {
                if case let .battle(enemyID) = stage.encounter {
                    ids.insert(enemyID)
                }
            }
        }
        return ids
    }

    public static func enemies(
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

    public static func triples(
        for tier: SimulationPowerTier,
        stageWeighted: Bool,
        heroes: [Combatant] = GameContent.heroes,
        pets: [Combatant] = GameContent.pets,
        enemies: [Enemy] = GameContent.enemies
    ) -> [BalanceSweepTriple] {
        let tierEnemies = enemies(
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

    public static func allTriples(
        heroes: [Combatant] = GameContent.heroes,
        pets: [Combatant] = GameContent.pets,
        enemies: [Enemy] = GameContent.enemies
    ) -> [BalanceSweepTriple] {
        triples(for: .early, stageWeighted: false, heroes: heroes, pets: pets, enemies: enemies)
    }

    public static func representativeHero(
        id: String = BalanceSweepDefaults.representativeHeroID,
        heroes: [Combatant] = GameContent.heroes
    ) -> Combatant? {
        heroes.first { $0.id == id }
    }

    public static func representativePet(
        id: String = BalanceSweepDefaults.representativePetID,
        pets: [Combatant] = GameContent.pets
    ) -> Combatant? {
        pets.first { $0.id == id }
    }
}

public enum BalanceSweepDefaults {
    public static let representativeHeroID = "knight"
    public static let representativePetID = "wolf"
    public static let runsPerMatchup = 20
    public static let loadoutSamplesPerMatchup = 5
    public static let baseSeed: UInt64 = 42_026
    public static let maxTicks = 100
    public static let minFightTicks = 10
}
