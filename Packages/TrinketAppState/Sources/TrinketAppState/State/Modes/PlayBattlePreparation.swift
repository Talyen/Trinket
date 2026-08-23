import BattleEngine
import Foundation
import TrinketContent

/// Shared battle-preparation math for every play mode: resolves a catalog
/// enemy and scales it to the party-adjusted authored level.
enum PlayBattlePreparation {
    static func scaledEncounter(
        enemyID: String?,
        authoredLevel: Int,
        partyAverageLevel: Int
    ) -> (combatant: Combatant, level: Int)? {
        guard let enemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID)
        else { return nil }
        let level = EncounterLevelResolver.partyAdjusted(
            authoredLevel,
            partyAverageLevel: partyAverageLevel
        )
        return (CombatantLevelScaler.scale(enemy: catalogEnemy, level: level), level)
    }
}
