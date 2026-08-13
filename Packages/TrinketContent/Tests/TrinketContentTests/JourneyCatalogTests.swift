import Testing
@testable import TrinketContent

struct JourneyCatalogTests {
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
}
