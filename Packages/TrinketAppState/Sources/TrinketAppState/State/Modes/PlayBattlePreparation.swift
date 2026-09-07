import BattleEngine
import Foundation
import TrinketContent

enum PlayBattlePreparation {
    static func scaledEncounter(
        enemyID: String?,
        level: Int,
    ) -> (combatant: Combatant, level: Int)? {
        guard let enemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID)
        else { return nil }
        return (CombatantLevelScaler.scale(enemy: catalogEnemy, level: level), level)
    }
}
