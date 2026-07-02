import XCTest
@testable import Trinket

final class VisibleStageDeckTests: XCTestCase {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    func testActiveStageDeckIncludesPreviousActiveAndFutureStage() {
        var progress = JourneyProgressState.initial
        let activeStage = chapter.stages[2]
        progress.activeStageID = activeStage.id

        let deck = VisibleStageDeck(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        XCTAssertEqual(deck.cards.count, 3)
        XCTAssertEqual(deck.scrollTargetID, activeStage.id)

        guard case let .stage(activeNode) = deck.cards[1] else {
            return XCTFail("Expected active stage card in center position")
        }
        XCTAssertEqual(activeNode.stage.id, activeStage.id)
        XCTAssertEqual(activeNode.state, .active)
    }

    func testFirstActiveStageOmitsPreviousCard() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        progress.activeStageID = firstStage.id

        let deck = VisibleStageDeck(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        XCTAssertEqual(deck.cards.count, 2)
        XCTAssertEqual(deck.scrollTargetID, firstStage.id)

        guard case let .stage(activeNode) = deck.cards[0] else {
            return XCTFail("Expected active stage as first card")
        }
        XCTAssertEqual(activeNode.stage.id, firstStage.id)
        XCTAssertEqual(activeNode.state, .active)
    }

    func testEmptyChapterProducesEmptyDeck() {
        let emptyChapter = Chapter(
            id: "empty-chapter",
            number: 99,
            title: "Empty",
            theme: .verdantForest,
            stages: []
        )

        let deck = VisibleStageDeck(
            chapters: GameContent.chapters,
            chapter: emptyChapter,
            progress: .initial
        )

        XCTAssertTrue(deck.cards.isEmpty)
        XCTAssertNil(deck.scrollTargetID)
    }

    func testFinalStageDeckIncludesChapterGate() {
        var progress = JourneyProgressState.initial
        let finalStage = chapter.stages[9]
        progress.activeStageID = finalStage.id
        progress.completedStageIDs = Set(chapter.stages.dropLast().map(\.id))

        let deck = VisibleStageDeck(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        guard case let .chapterGate(gateChapter) = deck.cards.last else {
            return XCTFail("Expected chapter gate card at end of deck")
        }
        XCTAssertEqual(gateChapter.number, 2)
        XCTAssertEqual(gateChapter.id, StageMapID.placeholderGate(afterChapterNumber: 2))
    }

    func testCompletedChapterScrollsToGate() {
        var progress = JourneyProgressState.initial
        progress.completedStageIDs = Set(chapter.stages.map(\.id))
        progress.activeStageID = nil
        progress.lastCompletedStageID = chapter.stages.last?.id

        let deck = VisibleStageDeck(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )

        XCTAssertEqual(
            deck.scrollTargetID,
            StageMapID.chapterGate(for: Chapter(
                id: StageMapID.placeholderGate(afterChapterNumber: 2),
                number: 2,
                title: "",
                theme: chapter.theme,
                stages: []
            ))
        )
        guard case let .chapterGate(gateChapter) = deck.cards.last else {
            return XCTFail("Expected chapter gate card")
        }
        XCTAssertEqual(gateChapter.number, 2)
    }
}
