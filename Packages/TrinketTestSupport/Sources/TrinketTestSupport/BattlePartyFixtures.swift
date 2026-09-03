import TrinketContent
import TrinketCore

public enum BattlePartyFixtures {
    public struct BattleParty: Sendable {
        public let hero: Combatant
        public let companion: Combatant
        public let enemy: Combatant

        public init(hero: Combatant, companion: Combatant, enemy: Combatant) {
            self.hero = hero
            self.companion = companion
            self.enemy = enemy
        }
    }

    public static func quickWinParty(
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        enemy: Combatant? = nil,
        heroAbilities: [Ability] = [.slash],
        enemyMaxHealth: Int = 1,
    ) -> BattleParty {
        precondition(enemyMaxHealth > 0, "enemyMaxHealth must be positive")
        return BattleParty(
            hero: hero ?? CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                actionIntervalTurns: CombatantFixtures.quickWinTurnInterval,
                abilities: heroAbilities,
            ),
            companion: companion ?? CombatantFixtures.passiveCompanion(),
            enemy: enemy ?? CombatantFixtures.passiveEnemy(
                maxHealth: enemyMaxHealth,
            ),
        )
    }
}
