import TrinketContent
import TrinketPersistence
import XCTest
@testable import Trinket

final class JourneyMapPresentationTests: XCTestCase {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    func testActiveJourneyScrollsToActiveStage() {
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

        XCTAssertEqual(scrollTargetID, activeStage.id)
        XCTAssertTrue(rows.contains { row in
            if case let .stage(stage, state) = row {
                return stage.id == activeStage.id && state == .active
            }
            return false
        })
    }

    func testActiveStageAppearsInRows() {
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
        XCTAssertTrue(stageIDs.contains(activeStage.id))
        XCTAssertEqual(scrollTargetID, activeStage.id)
    }

    func testCompletedStagesAreExcludedFromRows() {
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
        XCTAssertFalse(stageIDs.contains(firstStage.id))
    }

    func testJustCompletedStageIsExcludedFromRows() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        progress.complete(firstStage, in: GameContent.chapters)

        let rows = JourneyMapPresentation.chapterRows(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        XCTAssertFalse(
            rows.contains {
                guard case let .stage(_, state) = $0 else { return false }
                return state == .justCompleted
            }
        )
    }

    func testRowsEndWithChapterGate() {
        var progress = JourneyProgressState.initial
        progress.activeStageID = chapter.stages[0].id

        let rows = JourneyMapPresentation.chapterRows(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        guard case let .chapterGate(gateChapter) = rows.last else {
            return XCTFail("Expected chapter gate row")
        }
        XCTAssertEqual(gateChapter.number, 2)
    }

    func testCompletedChapterScrollsToGate() {
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
        XCTAssertEqual(scrollTargetID, StageMapID.chapterGate(for: gateChapter))
        XCTAssertTrue(rows.contains { row in
            if case let .chapterGate(chapter) = row {
                return chapter.number == gateChapter.number
            }
            return false
        })
    }

    func testScrollTargetFallsBackToChapterGateWhenChapterComplete() {
        var progress = JourneyProgressState.initial
        for stage in chapter.stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        let scrollTargetID = JourneyMapPresentation.scrollFocusID(
            for: progress,
            chapter: chapter,
            chapters: GameContent.chapters
        )

        XCTAssertEqual(
            scrollTargetID,
            StageMapID.chapterGate(
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

    func testGateChapterUsesPlaceholderWhenNextChapterMissing() throws {
        let lastChapter = try XCTUnwrap(GameContent.chapters.last)
        let gateChapter = JourneyMapPresentation.gateChapter(after: lastChapter, in: GameContent.chapters)

        XCTAssertEqual(gateChapter.id, StageMapID.placeholderGate(afterChapterNumber: gateChapter.number))
    }
}
