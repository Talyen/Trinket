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

    @Test func recruitMysteryStageUsesCombatantPortraitArt() throws {
        let stage = try #require(GameContent.chapters[0].stages.first { $0.id == "chapter-1-stage-2" })

        #expect(stage.encounter == .mysteryEvent(eventID: "recruit-bear"))
        #expect(GameContent.encounterArtID(for: stage) == nil)
        #expect(stage.encounterArtReference == nil)
        let art = try #require(stage.encounterCombatantArtReference)
        #expect(art == ArtCatalog.combatantArtByID["bear"])
        #expect(stage.encounterSubjectName == "Bear")
        #expect(abs(stage.encounter.artAspectRatio - (4.0 / 3.0)) < 0.000_1)
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
