import Foundation
import TrinketContent

public extension JourneyProgressState {
    func isActive(_ stage: Stage) -> Bool {
        activeStageID == stage.id
    }

    func isCompleted(_ stage: Stage) -> Bool {
        completedStageIDs.contains(stage.id)
    }

    func isLastCompleted(_ stage: Stage) -> Bool {
        lastCompletedStageID == stage.id
    }

    func hasClaimedRewards(for stage: Stage) -> Bool {
        claimedRewardStageIDs.contains(stage.id)
    }

    mutating func markRewardsClaimed(for stage: Stage) {
        claimedRewardStageIDs.insert(stage.id)
    }

    /// True when every stage in the active chapter is complete and the player has not
    /// yet moved into the next chapter (or the campaign is finished).
    func isActiveChapterCleared(in chapters: [Chapter] = GameContent.chapters) -> Bool {
        guard activeStageID == nil,
              let chapter = chapters.first(where: { $0.id == activeChapterID }),
              !chapter.stages.isEmpty
        else { return false }
        return chapter.stages.allSatisfy { completedStageIDs.contains($0.id) }
    }

    /// Next chapter waiting behind an explicit advance, if any.
    func pendingNextChapter(in chapters: [Chapter] = GameContent.chapters) -> Chapter? {
        guard isActiveChapterCleared(in: chapters),
              let index = chapters.firstIndex(where: { $0.id == activeChapterID }),
              chapters.indices.contains(index + 1)
        else { return nil }
        return chapters[index + 1]
    }

    mutating func complete(_ stage: Stage, in chapters: [Chapter]) {
        completedStageIDs.insert(stage.id)
        lastCompletedStageID = stage.id

        if let nextStage = Self.nextStage(after: stage, in: chapters) {
            if nextStage.chapterID == stage.chapterID {
                activeChapterID = nextStage.chapterID
                activeStageID = nextStage.id
            } else {
                // Park on the cleared chapter until the player advances.
                activeChapterID = stage.chapterID
                activeStageID = nil
            }
        } else {
            activeStageID = nil
        }
    }

    /// Moves from a cleared chapter into the next chapter's first stage.
    @discardableResult
    mutating func advanceToNextChapter(in chapters: [Chapter] = GameContent.chapters) -> Bool {
        guard let nextChapter = pendingNextChapter(in: chapters),
              let firstStage = nextChapter.stages.first
        else { return false }
        activeChapterID = nextChapter.id
        activeStageID = firstStage.id
        return true
    }

    /// Marks every stage in the given chapter complete and parks until the player advances.
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
        lastCompletedStageID = lastStage.id
        activeChapterID = chapter.id
        activeStageID = nil
    }

    /// Marks every catalog stage complete and parks the active pointer past the finale.
    mutating func completeAllStages(in chapters: [Chapter] = GameContent.chapters) {
        let allStages = chapters.flatMap(\.stages)
        guard let lastStage = allStages.last else { return }
        completedStageIDs = Set(allStages.map(\.id))
        claimedRewardStageIDs = completedStageIDs
        lastCompletedStageID = lastStage.id
        activeChapterID = lastStage.chapterID
        activeStageID = nil
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
