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

        #expect(homestead.buildOrUpgrade(definition, roster: &roster))

        #expect(homestead.tier(for: .wheatField) == 1)
        #expect(homestead.resources[.wood] == 10)
        #expect(homestead.resources[.stone] == 6)
        #expect(roster.gold == 4)
    }

    @Test func buildOrUpgradeSpendsGoldWhenCostRequiresIt() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .herbGarden))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 12, .food: 6],
            nodeTiers: [.wheatField: 1]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 10

        #expect(homestead.buildOrUpgrade(definition, roster: &roster))

        #expect(homestead.tier(for: .herbGarden) == 1)
        #expect(homestead.resources[.wood] == 0)
        #expect(homestead.resources[.food] == 0)
        #expect(roster.gold == 0)
    }

    @Test func lockedNodeCannotUpgradeBeforePrerequisites() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .blacksmithForge))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 100, .stone: 100, .iron: 100],
            nodeTiers: [.wheatField: 1]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 100

        #expect(!(homestead.buildOrUpgrade(definition, roster: &roster)))
        #expect(homestead.tier(for: .blacksmithForge) == 0)
    }

    @Test func adjustedMaterialRewardsAddsGranaryBonusForAllMaterials() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 3]
        )

        let adjusted = homestead.adjustedMaterialRewards([
            ResourceAmount(.wood, 8),
            ResourceAmount(.stone, 3)
        ])

        #expect(adjusted.first { $0.resource == .wood }?.quantity == 9)
        #expect(adjusted.first { $0.resource == .stone }?.quantity == 4)
    }

    @Test func adjustedMaterialRewardsAddsFoodBonusFromChickenCoop() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.chickenCoop: 2]
        )

        let adjusted = homestead.adjustedMaterialRewards([ResourceAmount(.food, 5)])

        #expect(adjusted.first { $0.resource == .food }?.quantity == 6)
    }

    @Test func adjustedMaterialRewardsAddsHerbBonusFromHerbGarden() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.herbGarden: 2]
        )

        let adjusted = homestead.adjustedMaterialRewards([ResourceAmount(.herbs, 2)])

        #expect(adjusted.first { $0.resource == .herbs }?.quantity == 3)
    }

    @Test func adjustedMaterialRewardsStacksFoodBonusesFromMultipleBuildings() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 2, .chickenCoop: 2]
        )

        let adjusted = homestead.adjustedMaterialRewards([ResourceAmount(.food, 4)])

        #expect(adjusted.first { $0.resource == .food }?.quantity == 6)
    }

    @Test func adjustedMaterialRewardsIgnoresGoldMaterials() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 3]
        )

        let adjusted = homestead.adjustedMaterialRewards([ResourceAmount(.gold, 10)])

        #expect(adjusted.isEmpty)
    }
}
