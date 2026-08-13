import Foundation
import TrinketCore

public enum EncounterLevelResolver {
    /// Journey mode: each chapter spans five enemy levels. Combat stages interpolate
    /// from the chapter base through chapter base + 4.
    public static func journeyEnemyLevel(for stage: Stage, in chapter: Chapter) -> Int {
        let chapterBaseLevel = (chapter.number - 1) * 5 + 1
        guard stage.encounter.isCombat else {
            return chapterBaseLevel
        }

        let battleStages = chapter.stages.filter(\.encounter.isCombat)
        guard let battleIndex = battleStages.firstIndex(where: { $0.id == stage.id }) else {
            return chapterBaseLevel
        }

        let maxOffset = 4
        let offset: Int = if battleStages.count <= 1 {
            0
        } else {
            (battleIndex * maxOffset) / (battleStages.count - 1)
        }
        return chapterBaseLevel + offset
    }

    /// Spires: enemy level is twice the floor number.
    public static func spireEnemyLevel(for floor: SpireFloor) -> Int {
        max(1, floor.floor * 2)
    }
}
