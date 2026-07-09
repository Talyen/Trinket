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

    @Test func chapterOneHasTenSequentialStages() throws {
        try #expect(chapter.stages.count == 10)

        for (index, stage) in chapter.stages.enumerated() {
            try #expect(stage.stageNumber == index + 1, "\(stage.id)")
            try #expect(stage.chapterNumber == 1, "\(stage.id)")
            try #expect(stage.chapterID == chapter.id, "\(stage.id)")
        }

        let stageIDs = chapter.stages.map(\.id)
        try #expect(Set(stageIDs).count == stageIDs.count, "Stage IDs must be unique")
    }

    @Test func finalStageIsBossEncounter() throws {
        let finalStage = try #require(chapter.stages.last)
        let enemyID = try #require(finalStage.encounter.battleEnemyID)
        let enemy = try #require(GameContent.enemy(matching: enemyID))

        try #expect(enemyID == "the_blight_treant")
        try #expect(enemy.isBoss)
    }

    @Test func nextStageReturnsNilAfterFinalStage() throws {
        let finalChapter = try #require(GameContent.chapters.last)
        let finalStage = try #require(finalChapter.stages.last)

        try #expect(JourneyProgressState.nextStage(after: finalStage, in: GameContent.chapters) == nil)
    }

    @Test func nextStageCrossesIntoFollowingChapter() throws {
        let chapterOneFinal = try #require(chapter.stages.last)
        let next = try #require(JourneyProgressState.nextStage(after: chapterOneFinal, in: GameContent.chapters))

        try #expect(next.chapterID == "chapter-2")
        try #expect(next.id == "chapter-2-stage-1")
    }

    @Test func isLastCompletedReflectsLastCompletedStageID() throws {
        var progress = JourneyProgressState.initial
        let firstStage = chapter.stages[0]
        let secondStage = chapter.stages[1]

        try #expect(!(progress.isLastCompleted(firstStage)))

        progress.complete(firstStage, in: GameContent.chapters)

        try #expect(progress.isLastCompleted(firstStage))
        try #expect(!(progress.isLastCompleted(secondStage)))
    }
}
