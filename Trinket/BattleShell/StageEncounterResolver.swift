import BattleEngine
import TrinketContent
import TrinketCore

struct StageEncounterEnemy {
    let combatant: Combatant
    let level: Int
}

enum StageEncounterResolver {
    static func resolve(for stage: Stage) -> StageEncounterEnemy? {
        guard let enemyID = stage.encounter.battleEnemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID),
              let chapter = GameContent.chapter(id: stage.chapterID)
        else { return nil }

        let level = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        return StageEncounterEnemy(
            combatant: CombatantLevelScaler.scale(enemy: catalogEnemy, level: level),
            level: level
        )
    }
}
