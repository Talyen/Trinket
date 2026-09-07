import Foundation
import TrinketCore

public enum EncounterLevelResolver {
    public static func campaignAdjusted(_ authoredLevel: Int, partyAverageLevel: Int) -> Int {
        let level = max(1, authoredLevel)
        return adjusted(level, partyAverageLevel: partyAverageLevel, minimum: max(1, level - 3))
    }

    public static func labyrinthAdjusted(_ authoredLevel: Int, partyAverageLevel: Int) -> Int {
        let level = max(1, authoredLevel)
        let bandMinimum = 1 + ((level - 1) / 5) * 5
        return adjusted(level, partyAverageLevel: partyAverageLevel, minimum: bandMinimum)
    }

    private static func adjusted(_ level: Int, partyAverageLevel: Int, minimum: Int) -> Int {
        let partyLevel = min(level, max(1, partyAverageLevel))
        let partyCeiling = partyLevel + min(3, level - partyLevel)
        return max(minimum, partyCeiling)
    }

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

    public static func spireEnemyLevel(for floor: SpireFloor) -> Int {
        max(1, floor.floor * 2)
    }

    public static func labyrinthEnemyLevel(for node: LabyrinthNode) -> Int {
        max(1, node.depth)
    }
}
