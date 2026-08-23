import Foundation
import TrinketCore

public enum EncounterLevelResolver {
    /// Bounded downward party scaling: enemies never rise above their authored level,
    /// and never sit more than this many levels above the active party's average.
    public static let downwardPartyOffset = 3

    /// Applies bounded downward scaling to an authored enemy level. Overleveled
    /// parties keep the authored level; underleveled parties pull enemies down to
    /// `partyAverageLevel + downwardPartyOffset`.
    public static func partyAdjusted(
        _ authoredLevel: Int,
        partyAverageLevel: Int
    ) -> Int {
        min(authoredLevel, partyAverageLevel + downwardPartyOffset)
    }

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

    /// Labyrinth: enemy level is the node's depth.
    public static func labyrinthEnemyLevel(for node: LabyrinthNode) -> Int {
        max(1, node.depth)
    }
}
