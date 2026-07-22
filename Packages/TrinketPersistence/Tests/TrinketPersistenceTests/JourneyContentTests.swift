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
            try #expect(chapter.stages.count == 10, "\(chapter.id) should have 10 stages")
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

            let bossEnemyID = try #require(stages[9].encounter.battleEnemyID)
            try #expect(GameContent.enemy(matching: bossEnemyID)?.isBoss == true)
            try #expect(stages[7].encounter == .shop)
        }

        let chapterOne = GameContent.chapters[0]
        try #expect(chapterOne.theme == .forest)
        try #expect(chapterOne.stages[1].encounter.recruitEventID == "recruit-bear")
        try #expect(chapterOne.stages[3].encounter.recruitEventID == "recruit-ranger")
        try #expect(chapterOne.stages[4].encounter == .mysteryEvent(eventID: ""))
        try #expect(chapterOne.stages[5].encounter.battleEnemyID == "mud_elemental")

        let chapterTwo = GameContent.chapters[1]
        try #expect(chapterTwo.theme == .dungeon)
        try #expect(chapterTwo.stages[1].encounter.recruitEventID == "recruit-rogue")
        try #expect(chapterTwo.stages[5].encounter.recruitEventID == StageEncounter.randomCompanionRecruitID)

        let chapterThree = GameContent.chapters[2]
        try #expect(chapterThree.theme == .desert)
        try #expect(chapterThree.stages[1].encounter.recruitEventID == "recruit-phoenix")
        try #expect(chapterThree.stages[2].encounter == .randomBattle)
        try #expect(chapterThree.stages[6].encounter == .recruit(eventID: ""))

        let chapterFour = GameContent.chapters[3]
        try #expect(chapterFour.theme == .tundra)
        try #expect(chapterFour.title == "Tundra")
        try #expect(chapterFour.stages[1].encounter.recruitEventID == "recruit-frost-whelp")
        try #expect(chapterFour.stages[9].encounter.battleEnemyID == "the_frostwarden")
    }

    @Test func placeholderEncountersMatchTheApprovedChapterLineup() throws {
        let expectedEncounterIDs = [
            [
                "slime", "recruit-bear", "goblin", "recruit-ranger", "mystery",
                "mud_elemental", "mystery", "shop", "will_o_wisp", "the_blight_treant"
            ],
            [
                "skeleton", "recruit-rogue", "mimic", "mystery", "necromancer",
                "random-companion", "living_armor", "shop", "mystery", "the_iron_bear"
            ],
            [
                "fire_elemental", "recruit-phoenix", "battle", "recruit-wizard", "battle",
                "mystery", "recruit", "shop", "battle", "the_forge_golem"
            ],
            [
                "frost_elemental", "recruit-frost-whelp", "battle", "mystery", "battle",
                "recruit", "mystery", "shop", "battle", "the_frostwarden"
            ]
        ]

        for (chapter, expectedIDs) in zip(GameContent.chapters, expectedEncounterIDs) {
            let actualIDs = chapter.stages.map { stage -> String in
                if let enemyID = stage.encounter.battleEnemyID {
                    return enemyID
                }
                if case let .recruit(eventID) = stage.encounter {
                    return eventID.isEmpty ? "recruit" : eventID
                }
                if case .mysteryEvent = stage.encounter {
                    return "mystery"
                }
                if case .randomBattle = stage.encounter {
                    return "battle"
                }
                if stage.encounter == .shop {
                    return "shop"
                }
                return stage.encounter.title.lowercased()
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
