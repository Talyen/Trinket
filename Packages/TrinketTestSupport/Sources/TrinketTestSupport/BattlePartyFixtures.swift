import Foundation
import TrinketContent
import TrinketCore

public enum BattlePartyFixtures {
    public struct QuickWinParty: Sendable {
        public let hero: Combatant
        public let companion: Combatant
        public let enemy: Combatant

        public init(hero: Combatant, companion: Combatant, enemy: Combatant) {
            self.hero = hero
            self.companion = companion
            self.enemy = enemy
        }
    }

    /// Hero with a fast basic attack, passive companion, and low-HP enemy for deterministic victory tests.
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
            companion: CombatantFixtures.combatant(
                id: "companion",
                role: .companion,
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
