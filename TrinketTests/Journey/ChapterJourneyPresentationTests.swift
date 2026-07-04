import XCTest
import TrinketContent
import TrinketPersistence
@testable import Trinket

final class ChapterJourneyPresentationTests: XCTestCase {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    func testActiveStageAppearsInRows() {
        var progress = JourneyProgressState.initial
        let activeStage = chapter.stages[2]
        progress.activeStageID = activeStage.id

        let presentation = ChapterJourneyPresentation(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        let stageIDs = presentation.rows.compactMap { row -> String? in
            guard case let .stage(node) = row else { return nil }
            return node.stage.id
        }
        XCTAssertTrue(stageIDs.contains(activeStage.id))
        XCTAssertEqual(presentation.scrollTargetID, activeStage.id)
    }

    func testCompletedStagesAreExcludedFromRows() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        progress.complete(firstStage, in: GameContent.chapters)

        let presentation = ChapterJourneyPresentation(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        let stageIDs = presentation.rows.compactMap { row -> String? in
            guard case let .stage(node) = row else { return nil }
            return node.stage.id
        }
        XCTAssertFalse(stageIDs.contains(firstStage.id))
    }

    func testJustCompletedStageIsExcludedFromRows() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        progress.complete(firstStage, in: GameContent.chapters)

        let presentation = ChapterJourneyPresentation(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        XCTAssertFalse(
            presentation.rows.contains {
                guard case let .stage(node) = $0 else { return false }
                return node.state == .justCompleted
            }
        )
    }

    func testRowsEndWithChapterGate() {
        var progress = JourneyProgressState.initial
        progress.activeStageID = chapter.stages[0].id

        let presentation = ChapterJourneyPresentation(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        guard case let .chapterGate(gateChapter) = presentation.rows.last else {
            return XCTFail("Expected chapter gate row")
        }
        XCTAssertEqual(gateChapter.number, 2)
    }

    func testScrollTargetFallsBackToChapterGateWhenChapterComplete() {
        var progress = JourneyProgressState.initial
        for stage in chapter.stages {
            progress.complete(stage, in: GameContent.chapters)
        }

        let presentation = ChapterJourneyPresentation(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        XCTAssertEqual(
            presentation.scrollTargetID,
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
}
