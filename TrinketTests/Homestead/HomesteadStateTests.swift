import XCTest
@testable import Trinket

final class HomesteadStateTests: XCTestCase {
    func testBuildOrUpgradeSpendsMaterialsAndGold() throws {
        let definition = try XCTUnwrap(GameContent.homesteadNode(matching: .hearth))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 20, .stone: 10],
            nodeTiers: [:]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 4

        XCTAssertTrue(homestead.buildOrUpgrade(definition, roster: &roster))

        XCTAssertEqual(homestead.tier(for: .hearth), 1)
        XCTAssertEqual(homestead.resources[.wood], 8)
        XCTAssertEqual(homestead.resources[.stone], 4)
        XCTAssertEqual(roster.gold, 4)
    }

    func testBuildOrUpgradeSpendsGoldWhenCostRequiresIt() throws {
        let definition = try XCTUnwrap(GameContent.homesteadNode(matching: .lumberCamp))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 12],
            nodeTiers: [.hearth: 1]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 10

        XCTAssertTrue(homestead.buildOrUpgrade(definition, roster: &roster))

        XCTAssertEqual(homestead.tier(for: .lumberCamp), 1)
        XCTAssertEqual(homestead.resources[.wood], 4)
        XCTAssertEqual(roster.gold, 0)
    }

    func testLockedNodeCannotUpgradeBeforePrerequisites() throws {
        let definition = try XCTUnwrap(GameContent.homesteadNode(matching: .blacksmithWorkshop))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 100, .stone: 100, .iron: 100],
            nodeTiers: [.hearth: 1]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 100

        XCTAssertFalse(homestead.buildOrUpgrade(definition, roster: &roster))
        XCTAssertEqual(homestead.tier(for: .blacksmithWorkshop), 0)
    }
}
