import Testing
import TrinketContent
@testable import Trinket

struct GameContentEncounterArtTests {
    @Test func mappedEventStagesResolveEncounterArt() throws {
        let stage = try #require(GameContent.chapters[0].stages.first { $0.id == "chapter-1-stage-2" })

        #expect(GameContent.encounterArtID(for: stage) == "mystery-sunlight-breaks-canopy")
        #expect(GameContent.encounterArtTitle(for: stage) == "Sunlit Trail")
        _ = try #require(stage.encounterArtReference)
        #expect(stage.encounterSubjectName == "Sunlit Trail")
    }

    @Test func unmappedBattleStageUsesEnemyArt() throws {
        let stage = try #require(GameContent.chapters[0].stages.first { $0.id == "chapter-1-stage-1" })

        #expect(GameContent.encounterArtID(for: stage) == nil)
        #expect(stage.encounterArtReference == nil)
        _ = try #require(stage.encounterCombatantArtReference)
        #expect(stage.encounterSubjectName == "Skeleton")
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
