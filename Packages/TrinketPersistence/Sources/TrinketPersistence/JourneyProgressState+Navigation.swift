import Foundation
import TrinketContent

public extension JourneyProgressState {
    public func isActive(_ stage: Stage) -> Bool {
        activeStageID == stage.id
    }

    public func isCompleted(_ stage: Stage) -> Bool {
        completedStageIDs.contains(stage.id)
    }

    public func isLastCompleted(_ stage: Stage) -> Bool {
        lastCompletedStageID == stage.id
    }

    public func hasClaimedRewards(for stage: Stage) -> Bool {
        claimedRewardStageIDs.contains(stage.id)
    }

    public mutating func markRewardsClaimed(for stage: Stage) {
        claimedRewardStageIDs.insert(stage.id)
    }

    public mutating func complete(_ stage: Stage, in chapters: [Chapter]) {
        completedStageIDs.insert(stage.id)
        lastCompletedStageID = stage.id

        if let nextStage = Self.nextStage(after: stage, in: chapters) {
            activeChapterID = nextStage.chapterID
            activeStageID = nextStage.id
        } else {
            activeStageID = nil
        }
    }

    public static func nextStage(after stage: Stage, in chapters: [Chapter]) -> Stage? {
        guard let chapterIndex = chapters.firstIndex(where: { $0.id == stage.chapterID }),
              let stageIndex = chapters[chapterIndex].stages.firstIndex(where: { $0.id == stage.id })
        else { return nil }

        let chapter = chapters[chapterIndex]
        let nextStageIndex = stageIndex + 1
        if chapter.stages.indices.contains(nextStageIndex) {
            return chapter.stages[nextStageIndex]
        }

        let nextChapterIndex = chapterIndex + 1
        guard chapters.indices.contains(nextChapterIndex) else { return nil }
        return chapters[nextChapterIndex].stages.first
    }
}
