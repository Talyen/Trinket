import XCTest
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
}
