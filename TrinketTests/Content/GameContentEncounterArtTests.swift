import Testing
import TrinketContent
@testable import Trinket

struct GameContentEncounterArtTests {
    @Test func mappedEventStagesResolveEncounterArt() throws {
        let stage = try #require(GameContent.chapters[1].stages.first { $0.id == "chapter-2-stage-4" })

        #expect(GameContent.encounterArtID(for: stage) == "destination-merchant-shop")
        #expect(GameContent.encounterArtTitle(for: stage) == "Merchant's Shop")
        _ = try #require(stage.encounterArtReference)
        #expect(stage.encounterSubjectName == "Merchant's Shop")
    }

    @Test func recruitMysteryStagesUseRoleArtAndHideExactReward() throws {
        let chapter = GameContent.chapters[0]
        let stage = try #require(chapter.stages.first { $0.id == "chapter-1-stage-2" })

        #expect(stage.encounter == .mysteryEvent(eventID: "recruit-bear"))
        #expect(GameContent.encounterArtID(for: stage) == nil)
        let art = try #require(stage.encounterArtReference)
        #expect(art == ArtCatalog.encounterArtByID["mystery-recruit-companions"])
        #expect(stage.encounterCombatantArtReference == nil)
        #expect(stage.encounterSubjectName == "Mystery")
        #expect(stage.encounterTypeTitle == "A New Friend")
        #expect(abs(stage.encounter.artAspectRatio - (4.0 / 3.0)) < 0.000_1)

        let heroStage = try #require(chapter.stages.first { $0.id == "chapter-1-stage-4" })
        #expect(heroStage.encounterArtReference == ArtCatalog.encounterArtByID["mystery-recruit-heroes"])
        #expect(heroStage.encounterCombatantArtReference == nil)
        #expect(heroStage.encounterSubjectName == "Mystery")
        #expect(heroStage.encounterTypeTitle == "A New Friend")
    }

    @Test func unmappedBattleStageUsesEnemyArt() throws {
        let stage = try #require(GameContent.chapters[0].stages.first { $0.id == "chapter-1-stage-1" })

        #expect(GameContent.encounterArtID(for: stage) == nil)
        #expect(stage.encounterArtReference == nil)
        _ = try #require(stage.encounterCombatantArtReference)
        #expect(stage.encounterSubjectName == "Slime")
    }

    @Test func shopStageUsesMerchantFallbackTitle() {
        let stage = Stage(
            id: "test-shop",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            flavorText: "",
            encounter: .shop,
            rewards: .empty
        )

        #expect(GameContent.encounterArtID(for: stage) == nil)
        #expect(stage.encounterSubjectName == "Merchant")
    }
}
