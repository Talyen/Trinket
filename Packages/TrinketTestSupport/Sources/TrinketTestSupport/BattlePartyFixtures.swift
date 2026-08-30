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

    public struct StandardParty: Sendable {
        public let hero: Combatant
        public let companion: Combatant
        public let enemy: Combatant

        public init(hero: Combatant, companion: Combatant, enemy: Combatant) {
            self.hero = hero
            self.companion = companion
            self.enemy = enemy
        }
    }

    public static func standardParty(
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        enemy: Combatant? = nil,
    ) -> StandardParty {
        StandardParty(
            hero: hero ?? CombatantFixtures.passiveHero(),
            companion: companion ?? CombatantFixtures.passiveCompanion(),
            enemy: enemy ?? CombatantFixtures.passiveEnemy(),
        )
    }

    public static func quickWinParty(
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        heroAbilities: [Ability] = [.slash],
        enemyMaxHealth: Int = 1,
    ) -> QuickWinParty {
        QuickWinParty(
            hero: hero ?? CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                actionIntervalTurns: 1,
                abilities: heroAbilities,
            ),
            companion: companion ?? CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(
                maxHealth: enemyMaxHealth,
            ),
        )
    }
}
