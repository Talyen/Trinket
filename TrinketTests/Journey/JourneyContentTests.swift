import XCTest
@testable import Trinket

final class JourneyContentTests: XCTestCase {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    func testEachBattleStageReferencesValidEnemy() {
        for stage in chapter.stages {
            guard let enemyID = stage.encounter.battleEnemyID else { continue }
            XCTAssertNotNil(
                GameContent.enemy(matching: enemyID),
                "Stage \(stage.id) references missing enemy \(enemyID)"
            )
        }
    }

    func testEachRewardItemTemplateExists() {
        for stage in chapter.stages {
            for templateID in stage.rewards.itemTemplateIDs {
                XCTAssertNotNil(
                    GameContent.itemTemplate(matching: templateID),
                    "Stage \(stage.id) references missing item template \(templateID)"
                )
            }
        }
    }

    func testChapterOneHasTenSequentialStages() {
        XCTAssertEqual(chapter.stages.count, 10)

        for (index, stage) in chapter.stages.enumerated() {
            XCTAssertEqual(stage.stageNumber, index + 1, stage.id)
            XCTAssertEqual(stage.chapterNumber, 1, stage.id)
            XCTAssertEqual(stage.chapterID, chapter.id, stage.id)
        }

        let stageIDs = chapter.stages.map(\.id)
        XCTAssertEqual(Set(stageIDs).count, stageIDs.count, "Stage IDs must be unique")
    }

    func testFinalStageIsBossEncounter() throws {
        let finalStage = try XCTUnwrap(chapter.stages.last)
        let enemyID = try XCTUnwrap(finalStage.encounter.battleEnemyID)
        let enemy = try XCTUnwrap(GameContent.enemy(matching: enemyID))

        XCTAssertEqual(enemyID, "the_blight_treant")
        XCTAssertTrue(enemy.isBoss)
    }

    func testNextStageReturnsNilAfterFinalStage() throws {
        let finalStage = try XCTUnwrap(chapter.stages.last)

        XCTAssertNil(JourneyProgressState.nextStage(after: finalStage, in: GameContent.chapters))
    }

    func testIsLastCompletedReflectsLastCompletedStageID() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        let secondStage = chapter.stages[1]

        XCTAssertFalse(progress.isLastCompleted(firstStage))

        progress.complete(firstStage, in: GameContent.chapters)

        XCTAssertTrue(progress.isLastCompleted(firstStage))
        XCTAssertFalse(progress.isLastCompleted(secondStage))
    }
}
