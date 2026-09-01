import TrinketContent
import TrinketCore

public enum CombatantFixtures {
    public static let deterministicBattleSeed: UInt64 = 1772
    public static let passiveTurnInterval: Int = 100
    public static let quickWinTurnInterval: Int = 1

    public static func combatant(
        id: String,
        name: String? = nil,
        role: Combatant.Role,
        maxHealth: Int = 50,
        maxMana: Int = 0,
        actionIntervalTurns: Int? = nil,
        abilities: [Ability] = [],
    ) -> Combatant {
        Combatant(
            id: id,
            name: name ?? formattedName(for: id),
            role: role,
            maxHealth: maxHealth,
            maxMana: maxMana,
            actionIntervalTurns: actionIntervalTurns,
            abilities: abilities,
        )
    }

    public static func passiveHero(
        id: String = "hero",
        maxHealth: Int = 50,
        maxMana: Int = 0,
        actionIntervalTurns: Int = passiveTurnInterval,
        abilities: [Ability] = [],
    ) -> Combatant {
        combatant(
            id: id,
            role: .hero,
            maxHealth: maxHealth,
            maxMana: maxMana,
            actionIntervalTurns: actionIntervalTurns,
            abilities: abilities,
        )
    }

    public static func passiveCompanion(
        id: String = "companion",
        maxHealth: Int = 50,
        maxMana: Int = 0,
        actionIntervalTurns: Int = passiveTurnInterval,
        abilities: [Ability] = [],
    ) -> Combatant {
        combatant(
            id: id,
            role: .companion,
            maxHealth: maxHealth,
            maxMana: maxMana,
            actionIntervalTurns: actionIntervalTurns,
            abilities: abilities,
        )
    }

    public static func passiveEnemy(
        id: String = "enemy",
        maxHealth: Int = 100,
        maxMana: Int = 0,
        actionIntervalTurns: Int = passiveTurnInterval,
        abilities: [Ability] = [],
    ) -> Combatant {
        combatant(
            id: id,
            role: .enemy,
            maxHealth: maxHealth,
            maxMana: maxMana,
            actionIntervalTurns: actionIntervalTurns,
            abilities: abilities,
        )
    }

    private static func formattedName(for id: String) -> String {
        id.split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
