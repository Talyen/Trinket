import XCTest
import TrinketContent
@testable import TrinketPersistence

final class PlayerSaveMergerTests: XCTestCase {
    func testMergeUnionsJourneyProgressAndTakesMaxGold() {
        var local = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100), gold: 10)
        local.journey.completedStageIDs.insert("chapter-1-stage-1")

        var remoteSave = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100), gold: 25)
        remoteSave.journey.claimedRewardStageIDs.insert("chapter-1-stage-1")

        let merged = PlayerSaveMerger.merge(local, remoteSave)

        XCTAssertEqual(merged.roster.gold, 25)
        XCTAssertTrue(merged.journey.completedStageIDs.contains("chapter-1-stage-1"))
        XCTAssertTrue(merged.journey.claimedRewardStageIDs.contains("chapter-1-stage-1"))
    }

    func testMergeGrantsMissingRewardsForRemoteOnlyClaimedStage() {
        var local = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100), gold: 0)
        local.journey.completedStageIDs.insert("chapter-1-stage-1")

        var remoteSave = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100), gold: 0)
        remoteSave.journey.completedStageIDs.insert("chapter-1-stage-1")
        remoteSave.journey.claimedRewardStageIDs.insert("chapter-1-stage-1")

        let merged = PlayerSaveMerger.merge(local, remoteSave)
        let firstStage = GameContent.chapters[0].stages[0]

        XCTAssertEqual(merged.roster.gold, firstStage.rewards.gold)
        XCTAssertTrue(merged.journey.claimedRewardStageIDs.contains("chapter-1-stage-1"))
        XCTAssertNotNil(merged.inventory.items.first { $0.id == "chapter-1-stage-1-shortsword-basic" })
    }

    func testMergeDoesNotDoubleGrantWhenRemoteAlreadyHasRewards() throws {
        var local = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100), gold: 0)
        local.journey.completedStageIDs.insert("chapter-1-stage-1")

        var remoteSave = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100), gold: 0)
        remoteSave.journey.completedStageIDs.insert("chapter-1-stage-1")
        remoteSave.journey.claimedRewardStageIDs.insert("chapter-1-stage-1")

        let firstStage = GameContent.chapters[0].stages[0]
        var context = StageCompletionContext(
            roster: remoteSave.playerRoster(inventoryItemIDs: []),
            inventory: remoteSave.inventory.inventory(),
            homestead: remoteSave.homestead.homestead(),
            journey: remoteSave.journey
        )
        let hero = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "bear" })
        StageCompletion.claimRewardsIfNeeded(
            for: firstStage,
            hero: hero,
            pet: pet,
            context: &context
        )
        remoteSave.roster = SavedRosterState(context.roster)
        remoteSave.inventory = SavedInventoryState(context.inventory)
        remoteSave.homestead = SavedHomesteadState(context.homestead)
        remoteSave.journey = context.journey

        let merged = PlayerSaveMerger.merge(local, remoteSave)

        XCTAssertEqual(merged.roster.gold, firstStage.rewards.gold)
        XCTAssertEqual(
            merged.inventory.items.filter { $0.id == "chapter-1-stage-1-shortsword-basic" }.count,
            1
        )
    }
}
