import Foundation
import TrinketCore

public enum EncounterLevelResolver {
    /// Journey mode: each chapter spans five enemy levels. Battle stages interpolate
    /// from the chapter base through chapter base + 4.
    public static func journeyEnemyLevel(for stage: Stage, in chapter: Chapter) -> Int {
        let chapterBaseLevel = (chapter.number - 1) * 5 + 1
        guard case .battle = stage.encounter else {
            return chapterBaseLevel
        }

        let battleStages = chapter.stages.filter {
            if case .battle = $0.encounter { return true }
            return false
        }
        guard let battleIndex = battleStages.firstIndex(where: { $0.id == stage.id }) else {
            return chapterBaseLevel
        }

        let maxOffset = 4
        let offset: Int
        if battleStages.count <= 1 {
            offset = 0
        } else {
            offset = (battleIndex * maxOffset) / (battleStages.count - 1)
        }
        return chapterBaseLevel + offset
    }
}
