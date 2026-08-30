import BattleEngine
import Foundation
import TrinketContent

enum PlayBattlePreparation {
    static func scaledEncounter(
        enemyID: String?,
        authoredLevel: Int,
        partyAverageLevel: Int,
    ) -> (combatant: Combatant, level: Int)? {
        guard let enemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID)
        else { return nil }
        let level = EncounterLevelResolver.partyAdjusted(
            authoredLevel,
            partyAverageLevel: partyAverageLevel,
        )
        return (CombatantLevelScaler.scale(enemy: catalogEnemy, level: level), level)
    }
}
