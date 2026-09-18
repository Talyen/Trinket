import TrinketContent
import TrinketCore

/// Shared combatant construction for tests.
///
/// This is the single home for combat fixtures.
public enum CombatantFixtures {
    public static let deterministicBattleSeed: UInt64 = 1772
    public static let passiveTurnInterval: Int = 100
    public static let quickWinTurnInterval: Int = 1

    /// Independent-but-deterministic seed stream for tests that must not share
    /// RNG state with the canonical seed. Prefer this over ad-hoc `&+` offsets
    /// so seed intent stays greppable and collision-free.
    public static func deterministicBattleSeedVariant(_ index: UInt64) -> UInt64 {
        deterministicBattleSeed &+ index
    }

    /// Flexible factory. A `nil` `actionIntervalTurns` means catalog/default
    /// turn cadence — it does **not** park the combatant. Pass
    /// `passiveTurnInterval` (or use the `passive*` presets) to park.
    public static func combatant(
        id: String,
        name: String? = nil,
        role: Combatant.Role,
        maxHealth: Int = 20,
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

    /// Parked-combatant core. The `passive*` presets forward with role-sensible
    /// defaults; call this directly for nonstandard parked roles.
    public static func passive(
        id: String,
        role: Combatant.Role,
        maxHealth: Int,
        maxMana: Int = 0,
        actionIntervalTurns: Int = passiveTurnInterval,
        abilities: [Ability] = [],
    ) -> Combatant {
        combatant(
            id: id,
            role: role,
            maxHealth: maxHealth,
            maxMana: maxMana,
            actionIntervalTurns: actionIntervalTurns,
            abilities: abilities,
        )
    }

    public static func passiveHero(
        id: String = "hero",
        maxHealth: Int = 20,
        maxMana: Int = 0,
        actionIntervalTurns: Int = passiveTurnInterval,
        abilities: [Ability] = [],
    ) -> Combatant {
        passive(
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
        maxHealth: Int = 20,
        maxMana: Int = 0,
        actionIntervalTurns: Int = passiveTurnInterval,
        abilities: [Ability] = [],
    ) -> Combatant {
        passive(
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
        passive(
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
