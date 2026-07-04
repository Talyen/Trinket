import TrinketContent
import TrinketPersistence

enum JourneyMapPresentation {
    static func gateChapter(after chapter: Chapter, in chapters: [Chapter]) -> Chapter {
        guard let chapterIndex = chapters.firstIndex(where: { $0.id == chapter.id }),
              chapters.indices.contains(chapterIndex + 1)
        else { return placeholderGateChapter(after: chapter) }
        return chapters[chapterIndex + 1]
    }

    static func placeholderGateChapter(after chapter: Chapter) -> Chapter {
        let nextNumber = chapter.number + 1
        return Chapter(
            id: StageMapID.placeholderGate(afterChapterNumber: nextNumber),
            number: nextNumber,
            title: "",
            theme: chapter.theme,
            stages: []
        )
    }

    static func stageNodeState(for stage: Stage, progress: JourneyProgressState) -> StageNodeState {
        if progress.isActive(stage) { return .active }
        if progress.isCompleted(stage) {
            return progress.isLastCompleted(stage) ? .justCompleted : .completed
        }
        return .future
    }

    static func scrollFocusID(
        for progress: JourneyProgressState,
        chapter: Chapter,
        chapters: [Chapter]
    ) -> String {
        if let activeStageID = progress.activeStageID {
            return activeStageID
        }
        return StageMapID.chapterGate(for: gateChapter(after: chapter, in: chapters))
    }
}
