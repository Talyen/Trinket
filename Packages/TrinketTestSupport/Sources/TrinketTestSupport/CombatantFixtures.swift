import Foundation
import TrinketContent
import TrinketCore

public enum CombatantFixtures {
    public static let deterministicBattleSeed: UInt64 = 1772

    public static func combatant(
        id: String,
        role: Combatant.Role,
        maxHealth: Int = 50,
        actionIntervalTurns: Int? = nil,
        abilities: [Ability] = [],
        primaryStats: PrimaryStats = PrimaryStats()
    ) -> Combatant {
        Combatant(
            id: id,
            name: id.capitalized,
            role: role,
            maxHealth: maxHealth,
            actionIntervalTurns: actionIntervalTurns,
            abilities: abilities,
            primaryStats: primaryStats
        )
    }

    public static func ability(
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
