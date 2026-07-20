import Testing
import TrinketContent
import TrinketPersistence
@testable import Trinket

struct JourneyMapPresentationTests {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    @Test func activeJourneyScrollsToAndIncludesActiveStage() {
        var progress = JourneyProgressState.initial
        let activeStage = chapter.stages[2]
        progress.activeStageID = activeStage.id

        let rows = JourneyMapPresentation.chapterRows(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )
        let scrollTargetID = JourneyMapPresentation.scrollFocusID(
            for: progress,
            chapter: chapter,
            chapters: GameContent.chapters
        )

        #expect(scrollTargetID == activeStage.id)
        let stageIDs = rows.compactMap { row -> String? in
            guard case let .stage(stage, _) = row else { return nil }
            return stage.id
        }
        #expect(stageIDs.contains(activeStage.id))
        #expect(rows.contains { row in
            if case let .stage(stage, state) = row {
                return stage.id == activeStage.id && state == .active
            }
            return false
        })
    }

    @Test func completedAndJustCompletedStagesAreExcludedFromRows() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        progress.complete(firstStage, in: GameContent.chapters)

        let rows = JourneyMapPresentation.chapterRows(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        let stageIDs = rows.compactMap { row -> String? in
            guard case let .stage(stage, _) = row else { return nil }
            return stage.id
        }
        #expect(!(stageIDs.contains(firstStage.id)))
        #expect(!rows.contains {
            guard case let .stage(_, state) = $0 else { return false }
            return state == .justCompleted
        })
    }

    @Test func rowsEndWithChapterGate() {
        var progress = JourneyProgressState.initial
        progress.activeStageID = chapter.stages[0].id

        let rows = JourneyMapPresentation.chapterRows(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        guard case let .chapterGate(gateChapter) = rows.last else {
            Issue.record("Expected chapter gate row")

            return
        }
        #expect(gateChapter.number == 2)
    }

    @Test func scrollTargetMovesToNextChapterWhenChapterCompletes() {
        var progress = JourneyProgressState.initial
        for stage in chapter.stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        #expect(progress.activeChapterID == "chapter-2")
        #expect(progress.activeStageID == "chapter-2-stage-1")
        #expect(
            JourneyMapPresentation.scrollFocusID(for: progress) == "chapter-2-stage-1"
        )
    }

    @Test func gateChapterUsesPlaceholderWhenNextChapterMissing() throws {
        let lastChapter = try #require(GameContent.chapters.last)
        let gateChapter = JourneyMapPresentation.gateChapter(after: lastChapter, in: GameContent.chapters)

        #expect(gateChapter.id == StageMapID.placeholderGate(afterChapterNumber: gateChapter.number))
    }
}
