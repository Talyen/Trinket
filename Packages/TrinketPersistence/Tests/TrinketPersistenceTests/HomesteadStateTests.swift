import XCTest
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

final class HomesteadStateTests: XCTestCase {
    func testBuildOrUpgradeSpendsMaterialsAndGold() throws {
        let definition = try XCTUnwrap(GameContent.homesteadNode(matching: .wheatField))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 20, .stone: 10],
            nodeTiers: [:]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 4

        XCTAssertTrue(homestead.buildOrUpgrade(definition, roster: &roster))

        XCTAssertEqual(homestead.tier(for: .wheatField), 1)
        XCTAssertEqual(homestead.resources[.wood], 10)
        XCTAssertEqual(homestead.resources[.stone], 6)
        XCTAssertEqual(roster.gold, 4)
    }

    func testBuildOrUpgradeSpendsGoldWhenCostRequiresIt() throws {
        let definition = try XCTUnwrap(GameContent.homesteadNode(matching: .herbGarden))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 12, .food: 6],
            nodeTiers: [.wheatField: 1]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 10

        XCTAssertTrue(homestead.buildOrUpgrade(definition, roster: &roster))

        XCTAssertEqual(homestead.tier(for: .herbGarden), 1)
        XCTAssertEqual(homestead.resources[.wood], 0)
        XCTAssertEqual(homestead.resources[.food], 0)
        XCTAssertEqual(roster.gold, 0)
    }

    func testLockedNodeCannotUpgradeBeforePrerequisites() throws {
        let definition = try XCTUnwrap(GameContent.homesteadNode(matching: .blacksmithForge))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 100, .stone: 100, .iron: 100],
            nodeTiers: [.wheatField: 1]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 100

        XCTAssertFalse(homestead.buildOrUpgrade(definition, roster: &roster))
        XCTAssertEqual(homestead.tier(for: .blacksmithForge), 0)
    }

    func testAdjustedMaterialRewardsAddsGranaryBonusForAllMaterials() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 3]
        )

        let adjusted = homestead.adjustedMaterialRewards([
            ResourceAmount(.wood, 8),
            ResourceAmount(.stone, 3)
        ])

        XCTAssertEqual(adjusted.first { $0.resource == .wood }?.quantity, 9)
        XCTAssertEqual(adjusted.first { $0.resource == .stone }?.quantity, 4)
    }

    func testAdjustedMaterialRewardsAddsFoodBonusFromChickenCoop() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.chickenCoop: 2]
        )

        let adjusted = homestead.adjustedMaterialRewards([ResourceAmount(.food, 5)])

        XCTAssertEqual(adjusted.first { $0.resource == .food }?.quantity, 6)
    }

    func testAdjustedMaterialRewardsAddsHerbBonusFromHerbGarden() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.herbGarden: 2]
        )

        let adjusted = homestead.adjustedMaterialRewards([ResourceAmount(.herbs, 2)])

        XCTAssertEqual(adjusted.first { $0.resource == .herbs }?.quantity, 3)
    }

    func testAdjustedMaterialRewardsIgnoresGoldMaterials() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 3]
        )

        let adjusted = homestead.adjustedMaterialRewards([ResourceAmount(.gold, 10)])

        XCTAssertTrue(adjusted.isEmpty)
    }
}
