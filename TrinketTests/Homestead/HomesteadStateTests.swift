import XCTest
@testable import Trinket

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
}
