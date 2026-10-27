import Foundation
import TrinketCore

public enum EncounterLevelResolver {
    static func contractEnemyLevel(difficulty: ContractDifficulty, partyAverageLevel: Int) -> Int {
        let level = max(1, partyAverageLevel)
        switch difficulty {
        case .easy: return max(1, level - 3)
        case .standard: return level
        case .hard: return SaturatedArithmetic.saturatingAdd(level, 3)
        }
    }

    static func campaignAdjusted(_ authoredLevel: Int, partyAverageLevel: Int) -> Int {
        let level = max(1, authoredLevel)
        return adjusted(level, partyAverageLevel: partyAverageLevel, minimum: max(1, level - 3))
    }

    static func labyrinthAdjusted(_ authoredLevel: Int, partyAverageLevel: Int) -> Int {
        let level = max(1, authoredLevel)
        let bandMinimum = 1 + ((level - 1) / 5) * 5
        return adjusted(level, partyAverageLevel: partyAverageLevel, minimum: bandMinimum)
    }

    private static func adjusted(_ level: Int, partyAverageLevel: Int, minimum: Int) -> Int {
        let partyLevel = min(level, max(1, partyAverageLevel))
        let partyCeiling = min(level, SaturatedArithmetic.saturatingAdd(partyLevel, 3))
        return max(minimum, partyCeiling)
    }

    public static func journeyEnemyLevel(for stage: Stage, in chapters: [Chapter]) -> Int {
        guard let chapter = chapters.first(where: { $0.id == stage.chapterID }) else { return 1 }
        return journeyEnemyLevel(for: stage, in: chapter)
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
        guard let battleIndex, battleCount > 1 else { return chapterBaseLevel }
        return chapterBaseLevel + (battleIndex * 4) / (battleCount - 1)
    }

    public static func spireEnemyLevel(for floor: SpireFloor) -> Int {
        max(1, floor.floor * 2)
    }

    public static func labyrinthEnemyLevel(for node: LabyrinthNode) -> Int {
        max(1, node.depth)
    }
}
