import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct HomesteadStateTests {
    private enum BuildSpendCase {
        case wheatFieldMaterials
        case herbGardenMaterials
    }

    @Test(arguments: [
        BuildSpendCase.wheatFieldMaterials,
        .herbGardenMaterials,
    ])
    private func buildOrUpgradeSpendsRequiredCosts(caseKind: BuildSpendCase) throws {
        switch caseKind {
        case .wheatFieldMaterials:
            let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
            var homestead = PlayerHomesteadState(
                resources: [.wood: 20, .herbs: 10],
                nodeTiers: [:]
            )
            var roster = PlayerRosterState.freshStart
            roster.gold = 4

            let built = homestead.buildOrUpgrade(definition, roster: &roster)
            try #expect(built)
            try #expect(homestead.tier(for: .wheatField) == 1)
            try #expect(homestead.resources[.wood] == 15)
            try #expect(homestead.resources[.herbs] == 5)
            try #expect(roster.gold == 4)

        case .herbGardenMaterials:
            let definition = try #require(GameContent.homesteadNode(matching: .herbGarden))
            var homestead = PlayerHomesteadState(
                resources: [.wood: 5, .herbs: 5],
                nodeTiers: [.wheatField: 1]
            )
            var roster = PlayerRosterState.freshStart
            roster.gold = 10

            let built = homestead.buildOrUpgrade(definition, roster: &roster)
            try #expect(built)
            try #expect(homestead.tier(for: .herbGarden) == 1)
            try #expect(homestead.resources[.wood] == 0)
            try #expect(homestead.resources[.herbs] == 0)
            try #expect(roster.gold == 10)
        }
    }

    @Test func lockedNodeCannotUpgradeBeforePrerequisites() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .blacksmithForge))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 100, .stone: 100, .iron: 100],
            nodeTiers: [.wheatField: 1]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 100

        let built = homestead.buildOrUpgrade(definition, roster: &roster)
        try #expect(!built)
        try #expect(homestead.tier(for: .blacksmithForge) == 0)
    }

    @Test func effectsReplaceLowerTiersInsteadOfStacking() throws {
        let tier1 = HomesteadEffects.from(nodeTiers: [.wheatField: 1])
        let tier3 = HomesteadEffects.from(nodeTiers: [.wheatField: 3])

        try #expect(tier1.heroModifiers == [.maximumHealth(4)])
        try #expect(tier1.companionModifiers == [.maximumHealth(4)])
        try #expect(tier3.heroModifiers == [.maximumHealth(12)])
        try #expect(tier3.companionModifiers == [.maximumHealth(12)])
    }

    @Test func wishingWellIncreasesGoldFindPercent() throws {
        let effects = HomesteadEffects.from(nodeTiers: [.wishingWell: 2])
        try #expect(effects.goldFindPercent == 10)
        try #expect(effects.adjustedGold(100) == 110)
    }

    @Test func moonlitSanctumIncreasesAstralChancePercent() throws {
        let effects = HomesteadEffects.from(nodeTiers: [.moonlitSanctum: 3])
        try #expect(effects.astralChanceBonusPercent == 15)
    }

    @Test func grantCapsMaterialBalanceAtMax() throws {
        var homestead = PlayerHomesteadState(
            resources: [.wood: 995, .stone: PlayerHomesteadState.maxMaterialBalance],
            nodeTiers: [:]
        )

        homestead.grant([
            ResourceAmount(.wood, 10),
            ResourceAmount(.stone, 5),
            ResourceAmount(.food, 3),
        ])

        try #expect(homestead.resources[.wood] == PlayerHomesteadState.maxMaterialBalance)
        try #expect(homestead.resources[.stone] == PlayerHomesteadState.maxMaterialBalance)
        try #expect(homestead.resources[.food] == 3)
    }

    @Test func receivableAmountsMirrorGrantClamp() throws {
        let uncapped = PlayerHomesteadState(resources: [:], nodeTiers: [:])
        let rewards = [
            ResourceAmount(.iron, 8),
            ResourceAmount(.wood, 4),
        ]
        try #expect(uncapped.receivableAmounts(from: rewards) == rewards)

        let partial = PlayerHomesteadState(
            resources: [
                .iron: PlayerHomesteadState.maxMaterialBalance - 2,
                .wood: PlayerHomesteadState.maxMaterialBalance,
            ],
            nodeTiers: [:]
        )
        try #expect(partial.receivableAmounts(from: rewards) == [
            ResourceAmount(.iron, 2),
        ])

        let full = PlayerHomesteadState(
            resources: [
                .iron: PlayerHomesteadState.maxMaterialBalance,
                .wood: PlayerHomesteadState.maxMaterialBalance,
            ],
            nodeTiers: [:]
        )
        try #expect(full.receivableAmounts(from: rewards).isEmpty)
    }

    @Test func productionPreservesFractionalProgressBetweenSettlements() throws {
        let start = Date(timeIntervalSince1970: 0)
        var homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 1],
            lastProductionAt: start
        )
        let roster = PlayerRosterState.freshStart

        homestead.settleProduction(
            at: start.addingTimeInterval(12 * 60 * 60),
            roster: roster
        )
        try #expect(abs(homestead.pendingProduction[.food, default: 0] - 0.5) < 0.0001)

        var collectingRoster = roster
        let collected = homestead.collectProduction(
            at: start.addingTimeInterval(24 * 60 * 60),
            roster: &collectingRoster
        )
        try #expect(collected == [ResourceAmount(.food, 1)])
        try #expect(homestead.resources[.food] == 1)
        try #expect(homestead.pendingProduction.isEmpty)
    }

    @Test func productionStopsAtCombinedWalletAndPendingCapacity() throws {
        let start = Date(timeIntervalSince1970: 0)
        var homestead = PlayerHomesteadState(
            resources: [.food: PlayerHomesteadState.maxMaterialBalance - 1],
            nodeTiers: [.wheatField: 1],
            lastProductionAt: start
        )
        var roster = PlayerRosterState.freshStart

        homestead.settleProduction(
            at: start.addingTimeInterval(2 * PlayerHomesteadState.secondsPerDay),
            roster: roster
        )
        try #expect(homestead.pendingProduction[.food] == 1)
        try #expect(
            homestead.collectProduction(
                at: start.addingTimeInterval(2 * PlayerHomesteadState.secondsPerDay),
                roster: &roster
            ) == [ResourceAmount(.food, 1)]
        )
        try #expect(homestead.resources[.food] == PlayerHomesteadState.maxMaterialBalance)
    }

    @Test func goldProductionCollectsIntoRosterAndRespectsGoldCap() throws {
        let start = Date(timeIntervalSince1970: 0)
        var homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wishingWell: 1],
            lastProductionAt: start
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = PlayerRosterState.maxGoldBalance - 1

        homestead.settleProduction(
            at: start.addingTimeInterval(2 * PlayerHomesteadState.secondsPerDay),
            roster: roster
        )
        try #expect(homestead.pendingProduction[.gold] == 1)

        let collected = homestead.collectProduction(
            at: start.addingTimeInterval(2 * PlayerHomesteadState.secondsPerDay),
            roster: &roster
        )
        try #expect(collected == [ResourceAmount(.gold, 1)])
        try #expect(roster.gold == PlayerRosterState.maxGoldBalance)
        try #expect(homestead.pendingProduction.isEmpty)
    }

    @Test func materialGrantSettlesProductionBeforeApplyingReward() throws {
        let start = Date(timeIntervalSince1970: 0)
        var save = PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: start,
            journey: .initial,
            roster: .freshStart,
            inventory: .freshStart,
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wheatField: 1],
                lastProductionAt: start
            )
        )

        let granted = save.grantMaterials(
            [ResourceAmount(.food, PlayerHomesteadState.maxMaterialBalance)],
            at: start.addingTimeInterval(PlayerHomesteadState.secondsPerDay)
        )

        try #expect(granted == [ResourceAmount(.food, PlayerHomesteadState.maxMaterialBalance - 1)])
        try #expect(save.homestead.resources[.food] == PlayerHomesteadState.maxMaterialBalance - 1)
        try #expect(save.homestead.pendingProduction[.food] == 1)
    }

    @Test func goldGrantSettlesProductionAndReturnsActualAmount() throws {
        let start = Date(timeIntervalSince1970: 0)
        var roster = PlayerRosterState.freshStart
        roster.gold = 995
        var save = PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: start,
            journey: .initial,
            roster: roster,
            inventory: .freshStart,
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wishingWell: 1],
                lastProductionAt: start
            )
        )

        let granted = save.grantGold(10, at: start.addingTimeInterval(PlayerHomesteadState.secondsPerDay))

        try #expect(granted == 3)
        try #expect(save.roster.gold == PlayerRosterState.maxGoldBalance - 1)
        try #expect(save.homestead.pendingProduction[.gold] == 1)
    }
}
