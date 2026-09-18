import TrinketContent
import TrinketCore

/// Quick-win battle party for tests: the hero acts every turn while the
/// companion and the enemy stay parked. The party alone does not seed — pair
/// it with a seeded `BattleRunConfiguration` (via
/// `BattleRunConfigurationTestSupport.make` or
/// `BattleSessionTestSupport.makeConfiguredSession`) or a seeded `BattleState`.
///
/// Override parameters (`hero` / `companion` / `enemy`) win wholesale: passing
/// an override discards the matching knob (`heroAbilities` for `hero`,
/// `enemyMaxHealth` for `enemy`), so avoid mixing them.
public enum BattlePartyFixtures {
    /// Labeled party shape returned by `quickWinParty`.
    public typealias BattleParty = (hero: Combatant, companion: Combatant, enemy: Combatant)

    public static func quickWinParty(
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        enemy: Combatant? = nil,
        heroAbilities: [Ability] = [.slash],
        enemyMaxHealth: Int = 1,
    ) -> BattleParty {
        // Fail fast on programmer error. `Combatant` itself is unchecked, so
        // the fixture owns these invariants; a quick-win party needs a living
        // enemy and at least one hero card to win with.
        precondition(enemyMaxHealth > 0, "enemyMaxHealth must be positive")
        precondition(!heroAbilities.isEmpty, "heroAbilities must be non-empty for a quick-win party")
        return (
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
