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

        let presentation = ChapterJourneyPresentation(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        XCTAssertEqual(presentation.scrollTargetID, activeStage.id)
        XCTAssertTrue(presentation.rows.contains { row in
            if case let .stage(node) = row {
                return node.stage.id == activeStage.id && node.state == .active
            }
            return false
        })
    }

    func testCompletedChapterScrollsToGate() {
        var progress = JourneyProgressState.initial
        progress.completedStageIDs = Set(chapter.stages.map(\.id))
        progress.activeStageID = nil
        progress.lastCompletedStageID = chapter.stages.last?.id

        let presentation = ChapterJourneyPresentation(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        let gateChapter = JourneyMapPresentation.gateChapter(after: chapter, in: GameContent.chapters)
        XCTAssertEqual(presentation.scrollTargetID, StageMapID.chapterGate(for: gateChapter))
        XCTAssertTrue(presentation.rows.contains { row in
            if case let .chapterGate(chapter) = row {
                return chapter.number == gateChapter.number
            }
            return false
        })
    }

    func testGateChapterUsesPlaceholderWhenNextChapterMissing() throws {
        let lastChapter = try XCTUnwrap(GameContent.chapters.last)
        let gateChapter = JourneyMapPresentation.gateChapter(after: lastChapter, in: GameContent.chapters)

        XCTAssertEqual(gateChapter.id, StageMapID.placeholderGate(afterChapterNumber: gateChapter.number))
    }
}
