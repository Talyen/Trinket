import TrinketContent
import TrinketCore

public enum BattlePartyFixtures {
    /// Labeled party shape returned by `quickWinParty`.
    public typealias BattleParty = (hero: Combatant, companion: Combatant, enemy: Combatant)
    /// Quick-win party: the hero acts every turn while the companion and the
    /// enemy stay parked. The party alone does not seed — pair it with a
    /// seeded `BattleState` or session helper.
    ///
    /// `enemyMaxHealth` must be positive; violations are programmer error and
    /// trap, matching `BattleState`'s own `precondition` style.
    public static func quickWinParty(
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        enemy: Combatant? = nil,
        heroAbilities: [Ability] = [.slash],
        enemyMaxHealth: Int = 1,
    ) -> (hero: Combatant, companion: Combatant, enemy: Combatant) {
        precondition(enemyMaxHealth > 0, "enemyMaxHealth must be positive")
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
