import XCTest
import TrinketContent
import TrinketPersistence
@testable import Trinket

final class StageMapPresentationTests: XCTestCase {
    func testChapterGateIDUsesChapterIdentifier() {
        let chapter = GameContent.chapters[0]

        XCTAssertEqual(StageMapID.chapterGate(for: chapter), "chapter-gate-\(chapter.id)")
    }

    func testPlaceholderGateIDUsesChapterNumber() {
        XCTAssertEqual(StageMapID.placeholderGate(afterChapterNumber: 2), "chapter-gate-placeholder-2")
    }

    func testChapterJourneyRowIDMatchesStageOrGate() throws {
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)
        let node = VisibleStageNode(stage: stage, state: .active)
        let gateChapter = Chapter(
            id: StageMapID.placeholderGate(afterChapterNumber: 2),
            number: 2,
            title: "",
            theme: GameContent.chapters[0].theme,
            stages: []
        )

        XCTAssertEqual(ChapterJourneyRow.stage(node).id, stage.id)
        XCTAssertEqual(ChapterJourneyRow.chapterGate(gateChapter).id, StageMapID.chapterGate(for: gateChapter))
    }

    func testStageMapLabelFormatsChapterAndStageNumber() throws {
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first)

        XCTAssertEqual(stage.mapLabel, "Stage \(stage.chapterNumber)-\(stage.stageNumber)")
    }

    func testMapScrollRequestIdentifiesTarget() {
        let request = MapScrollRequest(targetID: "chapter-1-stage-2")

        XCTAssertEqual(request.targetID, "chapter-1-stage-2")
        XCTAssertNotNil(request.id)
    }
}
