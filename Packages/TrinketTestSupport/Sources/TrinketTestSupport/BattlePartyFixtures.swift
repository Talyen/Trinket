import Foundation
import TrinketContent
import TrinketCore

public enum BattlePartyFixtures {
    public struct QuickWinParty: Sendable {
        public let hero: Combatant
        public let pet: Combatant
        public let enemy: Combatant

        public init(hero: Combatant, pet: Combatant, enemy: Combatant) {
            self.hero = hero
            self.pet = pet
            self.enemy = enemy
        }
    }

    /// Hero with a fast basic attack, passive pet, and low-HP enemy for deterministic victory tests.
    public static func quickWinParty(
        heroAbilities: [Ability] = [.slash],
        enemyMaxHealth: Int = 1
    ) -> QuickWinParty {
        QuickWinParty(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                actionIntervalTicks: 1,
                abilities: heroAbilities
            ),
            pet: CombatantFixtures.combatant(
                id: "pet",
                role: .pet,
                actionIntervalTicks: 100,
                abilities: []
            ),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: enemyMaxHealth,
                actionIntervalTicks: 100,
                abilities: []
            )
        )
    }
}
