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

    @Test func completedChapterScrollsToLastStageWhileAwaitingAdvance() {
        var progress = JourneyProgressState.initial
        progress.completedStageIDs = Set(chapter.stages.map(\.id))
        progress.activeStageID = nil
        progress.activeChapterID = chapter.id
        progress.lastCompletedStageID = chapter.stages.last?.id

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

        #expect(scrollTargetID == chapter.stages.last?.id)
        #expect(rows.contains { row in
            if case let .chapterGate(gate) = row {
                return gate.number == 2
            }
            return false
        })
    }

    @Test func scrollTargetStaysOnClearedChapterUntilAdvance() {
        var progress = JourneyProgressState.initial
        for stage in chapter.stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        let scrollTargetID = JourneyMapPresentation.scrollFocusID(
            for: progress,
            chapter: chapter,
            chapters: GameContent.chapters
        )

        #expect(progress.activeStageID == nil)
        #expect(scrollTargetID == "chapter-1-stage-5")

        let advanced = progress.advanceToNextChapter()
        #expect(advanced)
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
