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
        if progress.isActive(stage) {
            return .active
        }
        if progress.isCompleted(stage) {
            return progress.isLastCompleted(stage) ? .justCompleted : .completed
        }
        return .future
    }

    static func chapterRows(
        chapters: [Chapter],
        chapter: Chapter,
        progress: JourneyProgressState
    ) -> [ChapterJourneyRow] {
        chapter.stages.compactMap { stage -> ChapterJourneyRow? in
            let state = stageNodeState(for: stage, progress: progress)
            guard state != .completed, state != .justCompleted else { return nil }
            return .stage(stage, state)
        } + [.chapterGate(gateChapter(after: chapter, in: chapters))]
    }

    static func scrollFocusID(
        for progress: JourneyProgressState,
        chapters: [Chapter] = GameContent.chapters
    ) -> String {
        let chapter = chapters.first { $0.id == progress.activeChapterID } ?? chapters[0]
        return scrollFocusID(for: progress, chapter: chapter, chapters: chapters)
    }

    static func scrollFocusID(
        for progress: JourneyProgressState,
        chapter: Chapter,
        chapters: [Chapter]
    ) -> String {
        if let activeStageID = progress.activeStageID {
            return activeStageID
        }
        if let lastStage = chapter.stages.last, progress.isCompleted(lastStage) {
            return lastStage.id
        }
        return StageMapID.chapterGate(for: gateChapter(after: chapter, in: chapters))
    }
}

enum ChapterJourneyRow: Identifiable {
    case stage(Stage, StageNodeState)
    case chapterGate(Chapter)

    var id: String {
        switch self {
        case let .stage(stage, _):
            stage.id
        case let .chapterGate(chapter):
            StageMapID.chapterGate(for: chapter)
        }
    }
}
