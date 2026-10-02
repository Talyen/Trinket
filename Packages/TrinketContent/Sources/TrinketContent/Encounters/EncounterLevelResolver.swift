import Foundation
import TrinketCore

public enum EncounterLevelResolver {
    public static func contractEnemyLevel(difficulty: ContractDifficulty, partyAverageLevel: Int) -> Int {
        let level = max(1, partyAverageLevel)
        switch difficulty {
        case .easy: return max(1, level - 3)
        case .standard: return level
        case .hard: return level + min(3, Int.max - level)
        }
    }

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

        var battleCount = 0
        var battleIndex: Int?
        for candidate in chapter.stages where candidate.encounter.isCombat {
            if battleIndex == nil, candidate.id == stage.id {
                battleIndex = battleCount
            }
            battleCount += 1
        }
        guard let battleIndex else {
            return chapterBaseLevel
        }

        let maxOffset = 4
        let offset: Int = if battleCount <= 1 {
            0
        } else {
            (battleIndex * maxOffset) / (battleCount - 1)
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
