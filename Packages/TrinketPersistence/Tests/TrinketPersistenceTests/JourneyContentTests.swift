import Testing
import TrinketContent
@testable import TrinketPersistence

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

    @Test func everyChapterHasFiveSequentialStages() throws {
        for chapter in GameContent.chapters {
            try #expect(chapter.stages.count == 5, "\(chapter.id)")

            for (index, stage) in chapter.stages.enumerated() {
                try #expect(stage.stageNumber == index + 1, "\(stage.id)")
                try #expect(stage.chapterNumber == chapter.number, "\(stage.id)")
                try #expect(stage.chapterID == chapter.id, "\(stage.id)")
            }

            let stageIDs = chapter.stages.map(\.id)
            try #expect(Set(stageIDs).count == stageIDs.count, "Stage IDs must be unique")
        }
    }

    @Test func everyChapterUsesTheCampaignEncounterCadence() throws {
        for chapter in GameContent.chapters {
            let stages = chapter.stages

            let openingEnemyID = try #require(stages[0].encounter.battleEnemyID)
            try #expect(GameContent.enemy(matching: openingEnemyID)?.isBoss == false)

            let recruitID = try #require(stages[1].encounter.mysteryEventID)
            try #expect(GameContent.mysteryEvent(matching: recruitID)?.isRecruit == true)

            let secondEnemyID = try #require(stages[2].encounter.battleEnemyID)
            try #expect(GameContent.enemy(matching: secondEnemyID)?.isBoss == false)

            if case .shop = stages[3].encounter {
                // Expected.
            } else {
                Issue.record("\(stages[3].id) must be a shop")
            }

            let bossEnemyID = try #require(stages[4].encounter.battleEnemyID)
            try #expect(GameContent.enemy(matching: bossEnemyID)?.isBoss == true)
        }
    }

    @Test func placeholderEncountersMatchTheApprovedChapterLineup() throws {
        let expectedEncounterIDs = [
            ["skeleton", "recruit-wolf", "mud_elemental", "shop", "the_blight_treant"],
            ["goblin", "recruit-wizard", "fire_elemental", "shop", "the_forge_golem"],
            ["will_o_wisp", "recruit-library-owl", "frost_elemental", "shop", "the_frostwarden"]
        ]

        for (chapter, expectedIDs) in zip(GameContent.chapters, expectedEncounterIDs) {
            let actualIDs = chapter.stages.map { stage in
                stage.encounter.battleEnemyID
                    ?? stage.encounter.mysteryEventID
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
