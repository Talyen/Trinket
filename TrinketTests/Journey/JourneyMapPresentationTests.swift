import TrinketContent
import TrinketPersistence
import Testing
@testable import Trinket

@Suite
struct JourneyMapPresentationTests {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    @Test func activeJourneyScrollsToActiveStage() {
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
        #expect(rows.contains { row in
            if case let .stage(stage, state) = row {
                return stage.id == activeStage.id && state == .active
            }
            return false
        })
    }

    @Test func activeStageAppearsInRows() {
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

        let stageIDs = rows.compactMap { row -> String? in
            guard case let .stage(stage, _) = row else { return nil }
            return stage.id
        }
        #expect(stageIDs.contains(activeStage.id))
        #expect(scrollTargetID == activeStage.id)
    }

    @Test func completedStagesAreExcludedFromRows() {
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
    }

    @Test func justCompletedStageIsExcludedFromRows() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        progress.complete(firstStage, in: GameContent.chapters)

        let rows = JourneyMapPresentation.chapterRows(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        #expect(!(
            rows.contains {
                guard case let .stage(_, state)) = $0 else { return false }
                return state == .justCompleted
            }
        )
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
            return Issue.record("Expected chapter gate row")
        }
        #expect(gateChapter.number == 2)
    }

    @Test func completedChapterScrollsToGate() {
        var progress = JourneyProgressState.initial
        progress.completedStageIDs = Set(chapter.stages.map(\.id))
        progress.activeStageID = nil
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

        let gateChapter = JourneyMapPresentation.gateChapter(after: chapter, in: GameContent.chapters)
        #expect(scrollTargetID == StageMapID.chapterGate(for: gateChapter))
        #expect(rows.contains { row in
            if case let .chapterGate(chapter) = row {
                return chapter.number == gateChapter.number
            }
            return false
        })
    }

    @Test func scrollTargetFallsBackToChapterGateWhenChapterComplete() {
        var progress = JourneyProgressState.initial
        for stage in chapter.stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        let scrollTargetID = JourneyMapPresentation.scrollFocusID(
            for: progress,
            chapter: chapter,
            chapters: GameContent.chapters
        )

        #expect(
            scrollTargetID == StageMapID.chapterGate(
                for: Chapter(
                    id: StageMapID.placeholderGate(afterChapterNumber: 2),
                    number: 2,
                    title: "",
                    theme: chapter.theme,
                    stages: []
                )
            )
        )
    }

    @Test func gateChapterUsesPlaceholderWhenNextChapterMissing() throws {
        let lastChapter = try #require(GameContent.chapters.last)
        let gateChapter = JourneyMapPresentation.gateChapter(after: lastChapter, in: GameContent.chapters)

        #expect(gateChapter.id == StageMapID.placeholderGate(afterChapterNumber: gateChapter.number))
    }
}
