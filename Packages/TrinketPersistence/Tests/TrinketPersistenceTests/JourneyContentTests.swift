import Testing
import TrinketContent
@testable import TrinketPersistence

@Suite
struct JourneyContentTests {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    @Test func eachRewardItemTemplateExists() throws {
        for stage in chapter.stages {
            for templateID in stage.rewards.itemTemplateIDs {
                _ = try #require(
                    GameContent.itemTemplate(matching: templateID),
                    "Stage \(stage.id) references missing item template \(templateID)"
                )
            }
        }
    }

    @Test func chapterOneHasTenSequentialStages() {
        #expect(chapter.stages.count == 10)

        for (index, stage) in chapter.stages.enumerated() {
            #expect(stage.stageNumber == index + 1, stage.id)
            #expect(stage.chapterNumber == 1, stage.id)
            #expect(stage.chapterID == chapter.id, stage.id)
        }

        let stageIDs = chapter.stages.map(\.id)
        #expect(Set(stageIDs).count == stageIDs.count, "Stage IDs must be unique")
    }

    @Test func finalStageIsBossEncounter() throws {
        let finalStage = try #require(chapter.stages.last)
        let enemyID = try #require(finalStage.encounter.battleEnemyID)
        let enemy = try #require(GameContent.enemy(matching: enemyID))

        #expect(enemyID == "the_blight_treant")
        #expect(enemy.isBoss)
    }

    @Test func nextStageReturnsNilAfterFinalStage() throws {
        let finalStage = try #require(chapter.stages.last)

        #expect(JourneyProgressState.nextStage(after: finalStage, in: GameContent.chapters == nil))
    }

    @Test func isLastCompletedReflectsLastCompletedStageID() {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        let secondStage = chapter.stages[1]

        #expect(!(progress.isLastCompleted(firstStage)))

        progress.complete(firstStage, in: GameContent.chapters)

        #expect(progress.isLastCompleted(firstStage))
        #expect(!(progress.isLastCompleted(secondStage)))
    }
}
