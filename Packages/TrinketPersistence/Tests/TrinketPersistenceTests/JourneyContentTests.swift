import Testing
import TrinketContent
@testable import TrinketPersistence

struct JourneyContentTests {
    private var chapter: Chapter {
        GameContent.chapters[0]
    }

    @Test func authoredStagesHaveEmptyStageRewards() throws {
        for chapter in GameContent.chapters {
            for stage in chapter.stages {
                try #expect(stage.rewards == .empty, "\(stage.id) should not author StageReward")
            }
        }
    }

    @Test func everyChapterHasSequentialStagesWithUniqueIDs() throws {
        for chapter in GameContent.chapters {
            for (index, stage) in chapter.stages.enumerated() {
                try #expect(stage.stageNumber == index + 1, "\(stage.id)")
                try #expect(stage.chapterNumber == chapter.number, "\(stage.id)")
                try #expect(stage.chapterID == chapter.id, "\(stage.id)")
            }

            let stageIDs = chapter.stages.map(\.id)
            try #expect(Set(stageIDs).count == stageIDs.count, "Stage IDs must be unique")
        }
    }

    @Test func chapterEncounterCadenceMatchesStructuralInvariants() throws {
        for chapter in GameContent.chapters {
            let stages = chapter.stages
            try #require(stages.count > 7)

            let openingEnemyID = try #require(stages[0].encounter.battleEnemyID)
            try #expect(GameContent.enemy(matching: openingEnemyID)?.isBoss == false)

            let bossEnemyID = try #require(stages.last?.encounter.battleEnemyID)
            try #expect(GameContent.enemy(matching: bossEnemyID)?.isBoss == true)
            try #expect(stages[7].encounter == .shop)
        }
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
}
