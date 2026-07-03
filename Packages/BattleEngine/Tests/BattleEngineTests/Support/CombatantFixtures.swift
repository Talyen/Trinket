import XCTest
import BattleEngine
import TrinketCore
import TrinketContent


enum CombatantFixtures {
    static func combatant(
        id: String,
        role: Combatant.Role,
        maxHealth: Int = 50,
        actionIntervalTicks: Int? = nil,
        abilities: [Ability] = [],
        primaryStats: PrimaryStats = PrimaryStats()
    ) -> Combatant {
        Combatant(
            id: id,
            name: id.capitalized,
            role: role,
            maxHealth: maxHealth,
            actionIntervalTicks: actionIntervalTicks,
            abilities: abilities,
            primaryStats: primaryStats
        )
    }

    static func ability(
        id: String = "test",
        name: String = "Test",
        tier: AbilityTier = .basic,
        directDamage: Int = 0,
        damageKeyword: Keyword = .physical,
        description: String = "Test"
    ) -> Ability {
        Ability(
            id: id,
            name: name,
            tier: tier,
            directDamage: directDamage,
            damageKeyword: damageKeyword,
            description: description
        )
    }
}
