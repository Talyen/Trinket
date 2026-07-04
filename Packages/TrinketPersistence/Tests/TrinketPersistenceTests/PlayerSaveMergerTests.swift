import XCTest
import TrinketContent
import TrinketCore
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

    func testMergePrefersHigherProgressionLevel() {
        var local = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100))
        local.roster.progressions["knight"] = CombatantProgression(level: 3, currentXP: 10, requiredXP: 220)

        var remote = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100))
        remote.roster.progressions["knight"] = CombatantProgression(level: 5, currentXP: 0, requiredXP: 400)

        let merged = PlayerSaveMerger.merge(local, remote)

        XCTAssertEqual(merged.roster.progressions["knight"]?.level, 5)
    }

    func testMergeUnionsInventoryItemsByID() throws {
        let shortswordTemplate = try XCTUnwrap(GameContent.itemTemplate(matching: "shortsword-basic"))
        let wandTemplate = try XCTUnwrap(GameContent.itemTemplate(matching: "wand-basic"))
        let localItem = InventoryItem(
            id: "local-item",
            templateID: shortswordTemplate.id,
            baseType: shortswordTemplate.baseType,
            rarity: .basic,
            displayName: shortswordTemplate.displayName,
            affixes: []
        )
        let remoteItem = InventoryItem(
            id: "remote-item",
            templateID: wandTemplate.id,
            baseType: wandTemplate.baseType,
            rarity: .basic,
            displayName: wandTemplate.displayName,
            affixes: []
        )

        var local = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100))
        local.inventory.items = [SavedInventoryItem(localItem)]

        var remote = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100))
        remote.inventory.items = [SavedInventoryItem(remoteItem)]

        let merged = PlayerSaveMerger.merge(local, remote)
        let ids = Set(merged.inventory.items.map(\.id))

        XCTAssertEqual(ids, ["local-item", "remote-item"])
    }

    func testMergeTakesMaxHomesteadResources() {
        var local = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100))
        local.homestead.resources = [.wood: 10, .stone: 4]

        var remote = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100))
        remote.homestead.resources = [.wood: 6, .stone: 9]

        let merged = PlayerSaveMerger.merge(local, remote)

        XCTAssertEqual(merged.homestead.resources[.wood], 10)
        XCTAssertEqual(merged.homestead.resources[.stone], 9)
    }
}
