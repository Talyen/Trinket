import Foundation
import TrinketContent

public extension JourneyProgressState {
    func isActive(_ stage: Stage) -> Bool {
        activeStageID == stage.id
    }

    func isCompleted(_ stage: Stage) -> Bool {
        completedStageIDs.contains(stage.id)
    }

    func hasClaimedRewards(for stage: Stage) -> Bool {
        claimedRewardStageIDs.contains(stage.id)
    }

    mutating func markRewardsClaimed(for stage: Stage) {
        claimedRewardStageIDs.insert(stage.id)
    }

    mutating func complete(_ stage: Stage, in chapters: [Chapter]) {
        completedStageIDs.insert(stage.id)

        if let nextStage = Self.nextStage(after: stage, in: chapters) {
            activeChapterID = nextStage.chapterID
            activeStageID = nextStage.id
        } else {
            activeChapterID = stage.chapterID
            activeStageID = nil
        }
    }

    /// Marks every stage in the given chapter complete and activates the next chapter.
    mutating func completeChapter(
        _ chapterID: String,
        in chapters: [Chapter] = GameContent.chapters
    ) {
        guard let chapter = chapters.first(where: { $0.id == chapterID }),
              let lastStage = chapter.stages.last
        else { return }
        let stageIDs = Set(chapter.stages.map(\.id))
        completedStageIDs.formUnion(stageIDs)
        claimedRewardStageIDs.formUnion(stageIDs)
        if let nextStage = Self.nextStage(after: lastStage, in: chapters) {
            activeChapterID = nextStage.chapterID
            activeStageID = nextStage.id
        } else {
            activeChapterID = chapter.id
            activeStageID = nil
        }
    }

    static func nextStage(after stage: Stage, in chapters: [Chapter]) -> Stage? {
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
