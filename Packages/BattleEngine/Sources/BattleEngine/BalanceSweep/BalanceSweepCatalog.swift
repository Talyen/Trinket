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
    public static func allTriples(
        heroes: [Combatant] = GameContent.heroes,
        pets: [Combatant] = GameContent.pets,
        enemies: [Enemy] = GameContent.enemies
    ) -> [BalanceSweepTriple] {
        heroes.flatMap { hero in
            pets.flatMap { pet in
                enemies.map { enemy in
                    BalanceSweepTriple(hero: hero, pet: pet, enemy: enemy)
                }
            }
        }
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
    public static let maxTicks = 500
}
