import XCTest
@testable import Trinket

final class GameContentEncounterArtTests: XCTestCase {
    func testMappedEventStagesResolveEncounterArt() throws {
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first { $0.id == "chapter-1-stage-2" })

        XCTAssertEqual(GameContent.encounterArtID(for: stage), "mystery-sunlight-breaks-canopy")
        XCTAssertEqual(GameContent.encounterArtTitle(for: stage), "Sunlit Trail")
        XCTAssertNotNil(stage.encounterArtReference)
        XCTAssertEqual(stage.encounterSubjectName, "Sunlit Trail")
    }

    func testUnmappedBattleStageUsesEnemyArt() throws {
        let stage = try XCTUnwrap(GameContent.chapters[0].stages.first { $0.id == "chapter-1-stage-1" })

        XCTAssertNil(GameContent.encounterArtID(for: stage))
        XCTAssertNotNil(stage.encounterArtReference)
        XCTAssertEqual(stage.encounterSubjectName, "Skeleton")
    }

    func testShopStageUsesMerchantFallbackTitle() {
        let stage = Stage(
            id: "test-shop",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            flavorText: "",
            encounter: .shop,
            rewards: .empty
        )

        XCTAssertNil(GameContent.encounterArtID(for: stage))
        XCTAssertEqual(stage.encounterSubjectName, "Merchant")
    }
}
