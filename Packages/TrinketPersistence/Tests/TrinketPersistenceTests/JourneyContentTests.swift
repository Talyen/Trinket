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

    @Test func chapterEncounterCadenceMatchesTheCurrentJourney() throws {
        for chapter in GameContent.chapters {
            let stages = chapter.stages

            let openingEnemyID = try #require(stages[0].encounter.battleEnemyID)
            try #expect(GameContent.enemy(matching: openingEnemyID)?.isBoss == false)

            let bossEnemyID = try #require(stages[4].encounter.battleEnemyID)
            try #expect(GameContent.enemy(matching: bossEnemyID)?.isBoss == true)
        }

        let chapterOne = GameContent.chapters[0]
        try #expect(chapterOne.stages[1].encounter.recruitEventID == "recruit-bear")
        try #expect(chapterOne.stages[3].encounter.recruitEventID == "recruit-ranger")
        try #expect(chapterOne.stages.contains { $0.encounter == .shop } == false)

        let chapterTwo = GameContent.chapters[1]
        try #expect(chapterTwo.stages[1].encounter.recruitEventID == "recruit-rogue")
        try #expect(chapterTwo.stages[3].encounter == .shop)

        let chapterThree = GameContent.chapters[2]
        try #expect(chapterThree.stages[1].encounter.recruitEventID == "recruit-library-owl")
        try #expect(chapterThree.stages[3].encounter == .shop)
    }

    @Test func placeholderEncountersMatchTheApprovedChapterLineup() throws {
        let expectedEncounterIDs = [
            ["slime", "recruit-bear", "goblin", "recruit-ranger", "the_blight_treant"],
            ["skeleton", "recruit-rogue", "mimic", "shop", "the_iron_bear"],
            ["will_o_wisp", "recruit-library-owl", "frost_elemental", "shop", "the_frostwarden"]
        ]

        for (chapter, expectedIDs) in zip(GameContent.chapters, expectedEncounterIDs) {
            let actualIDs = chapter.stages.map { stage in
                stage.encounter.battleEnemyID
                    ?? stage.encounter.eventID
                    ?? (stage.encounter == .shop ? "shop" : stage.encounter.title.lowercased())
            }
            try #expect(actualIDs == expectedIDs)
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
