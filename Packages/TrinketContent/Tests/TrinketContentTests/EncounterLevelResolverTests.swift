import XCTest
import TrinketContent

final class EncounterLevelResolverTests: XCTestCase {
    func testJourneyEnemyLevelSpansFiveLevelsPerChapter() throws {
        let chapter = try XCTUnwrap(GameContent.chapters.first)
        let battleStages = chapter.stages.filter {
            if case .battle = $0.encounter { return true }
            return false
        }

        let levels = battleStages.map { EncounterLevelResolver.journeyEnemyLevel(for: $0, in: chapter) }
        XCTAssertEqual(levels.first, 1)
        XCTAssertEqual(levels.last, 5)
        XCTAssertEqual(levels, levels.sorted())
        XCTAssertGreaterThanOrEqual(Set(levels).count, 4)
    }

    func testNonBattleStagesReturnChapterBaseLevel() throws {
        let chapter = try XCTUnwrap(GameContent.chapters.first)
        let eventStage = try XCTUnwrap(chapter.stages.first { if case .event = $0.encounter { return true } else { return false } })

        XCTAssertEqual(EncounterLevelResolver.journeyEnemyLevel(for: eventStage, in: chapter), 1)
    }
}
