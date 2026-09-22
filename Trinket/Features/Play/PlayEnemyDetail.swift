import TrinketContent
import TrinketCore
import TrinketFeatureSupport

@MainActor
extension CombatantCardDetail {
    static func playEnemy(
        combatant: Combatant,
        level: Int,
        labyrinthModifiers: [LabyrinthModifierDefinition] = [],
    ) -> CombatantCardDetail {
        CombatantCardDetail(
            combatant: combatant,
            progression: .at(level: level),
            labyrinthModifiers: labyrinthModifiers,
        )
    }
}

/// Single constructor for enemy inspect sheets across Play destinations.
///
/// Campaign, Contracts, and Spire destinations share the same
/// combatant-at-level detail; Labyrinth adds its node modifiers explicitly.
/// Call sites must keep passing those modifiers rather than dropping them.
@MainActor
func makePlayEnemyDetail(
    combatant: Combatant,
    level: Int,
    labyrinthModifiers: [LabyrinthModifierDefinition] = [],
) -> CombatantCardDetail {
    CombatantCardDetail.playEnemy(
        combatant: combatant,
        level: level,
        labyrinthModifiers: labyrinthModifiers,
    )
}
