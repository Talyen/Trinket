import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

@Suite
struct HomesteadStateTests {
    @Test func buildOrUpgradeSpendsMaterialsAndGold() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 20, .stone: 10],
            nodeTiers: [:]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 4

        try #expect(homestead.buildOrUpgrade(definition, roster: &roster))

        try #expect(homestead.tier(for: .wheatField) == 1)
        try #expect(homestead.resources[.wood] == 10)
        try #expect(homestead.resources[.stone] == 6)
        try #expect(roster.gold == 4)
    }

    @Test func buildOrUpgradeSpendsGoldWhenCostRequiresIt() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .herbGarden))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 12, .food: 6],
            nodeTiers: [.wheatField: 1]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 10

        try #expect(homestead.buildOrUpgrade(definition, roster: &roster))

        try #expect(homestead.tier(for: .herbGarden) == 1)
        try #expect(homestead.resources[.wood] == 0)
        try #expect(homestead.resources[.food] == 0)
        try #expect(roster.gold == 0)
    }

    @Test func lockedNodeCannotUpgradeBeforePrerequisites() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .blacksmithForge))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 100, .stone: 100, .iron: 100],
            nodeTiers: [.wheatField: 1]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 100

        try #expect(!(homestead.buildOrUpgrade(definition, roster: &roster)))
        try #expect(homestead.tier(for: .blacksmithForge) == 0)
    }

    @Test func adjustedMaterialRewardsAddsGranaryBonusForAllMaterials() throws {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 3]
        )

        let adjusted = homestead.adjustedMaterialRewards([
            ResourceAmount(.wood, 8),
            ResourceAmount(.stone, 3)
        ])

        try #expect(adjusted.first { $0.resource == .wood }?.quantity == 9)
        try #expect(adjusted.first { $0.resource == .stone }?.quantity == 4)
    }

    @Test func adjustedMaterialRewardsAddsFoodBonusFromChickenCoop() throws {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.chickenCoop: 2]
        )

        let adjusted = homestead.adjustedMaterialRewards([ResourceAmount(.food, 5)])

        try #expect(adjusted.first { $0.resource == .food }?.quantity == 6)
    }

    @Test func adjustedMaterialRewardsAddsHerbBonusFromHerbGarden() throws {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.herbGarden: 2]
        )

        let adjusted = homestead.adjustedMaterialRewards([ResourceAmount(.herbs, 2)])

        try #expect(adjusted.first { $0.resource == .herbs }?.quantity == 3)
    }

    @Test func adjustedMaterialRewardsStacksFoodBonusesFromMultipleBuildings() throws {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 2, .chickenCoop: 2]
        )

        let adjusted = homestead.adjustedMaterialRewards([ResourceAmount(.food, 4)])

        try #expect(adjusted.first { $0.resource == .food }?.quantity == 6)
    }

    @Test func adjustedMaterialRewardsIgnoresGoldMaterials() throws {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 3]
        )

        let adjusted = homestead.adjustedMaterialRewards([ResourceAmount(.gold, 10)])

        try #expect(adjusted.isEmpty)
    }
}
