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

    @Test func `crystal production survives reload and collects both resources once`() throws {
        let start = Date(timeIntervalSince1970: 1000)
        var state = PlayerHomesteadState(resources: [:], nodeTiers: [.crystalGarden: 4], lastProductionAt: start)
        var roster = PlayerRosterState.freshStart
        state.settleProduction(at: start.addingTimeInterval(43200), roster: roster)
        state = try JSONDecoder().decode(PlayerHomesteadState.self, from: JSONEncoder().encode(state))
        let end = start.addingTimeInterval(86400)
        let first = state.collectProduction(at: end, roster: &roster)
        #expect(Set(first) == Set([ResourceAmount(.gems, 4), ResourceAmount(.stone, 4)]))
        #expect(state.collectProduction(at: end, roster: &roster).isEmpty)
    }

    @Test(arguments: [
        BuildSpendCase.wheatFieldMaterials,
        .herbGardenMaterials,
    ])
    private func `build or upgrade spends required costs`(caseKind: BuildSpendCase) throws {
        switch caseKind {
        case .wheatFieldMaterials:
            let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
            var homestead = PlayerHomesteadState(
                resources: [.wood: 20, .herbs: 10],
                nodeTiers: [:],
            )
            var roster = PlayerRosterState.freshStart
            roster.gold = 4

            let built = homestead.buildOrUpgrade(definition, roster: &roster)
            try #expect(built)
            try #expect(homestead.tier(for: .wheatField) == 1)
            try #expect(homestead.resources[.wood] == 16)
            try #expect(homestead.resources[.herbs] == 5)
            try #expect(roster.gold == 4)

        case .herbGardenMaterials:
            let definition = try #require(GameContent.homesteadNode(matching: .herbGarden))
            var homestead = PlayerHomesteadState(
                resources: [.wood: 5, .herbs: 5],
                nodeTiers: [.wheatField: 1],
            )
            var roster = PlayerRosterState.freshStart
            roster.gold = 10

            let built = homestead.buildOrUpgrade(definition, roster: &roster)
            try #expect(built)
            try #expect(homestead.tier(for: .herbGarden) == 1)
            try #expect(homestead.resources[.wood] == 1)
            try #expect(homestead.resources[.herbs] == 0)
            try #expect(roster.gold == 10)
        }
    }

    @Test(arguments: GameContent.homesteadNodes)
    func `any node can be the first building when its materials are available`(definition: HomesteadNodeDefinition) throws {
        let tier = try #require(definition.tier(1))
        var homestead = PlayerHomesteadState.freshStart
        var roster = PlayerRosterState.freshStart
        for amount in tier.cost {
            if amount.resource == .gold {
                roster.gold = amount.quantity
            } else {
                homestead.resources[amount.resource] = amount.quantity
            }
        }
        #expect(homestead.buildOrUpgrade(definition, roster: &roster))
        #expect(homestead.nodeTiers == [definition.id: 1])
        for amount in tier.cost {
            #expect(homestead.balance(for: amount.resource, roster: roster) == 0)
        }
    }

    @Test func `effects replace lower tiers instead of stacking`() throws {
        let tier1 = HomesteadEffects.from(nodeTiers: [.wheatField: 1])
        let tier3 = HomesteadEffects.from(nodeTiers: [.wheatField: 3])

        try #expect(tier1.heroModifiers == [.maximumHealth(4)])
        try #expect(tier1.companionModifiers.isEmpty)
        try #expect(tier3.heroModifiers == [.maximumHealth(12)])
        try #expect(tier3.companionModifiers.isEmpty)
    }

    @Test func `wishing well adds flat gold to positive rewards`() throws {
        let effects = HomesteadEffects.from(nodeTiers: [.wishingWell: 2])
        try #expect(effects.goldFindFlat == 2)
        try #expect(effects.adjustedGold(100) == 102)
    }

    @Test func `moonlit sanctum increases astral chance percent`() throws {
        let effects = HomesteadEffects.from(nodeTiers: [.moonlitSanctum: 3])
        try #expect(effects.astralChanceBonusPercent == 15)
    }

    @Test func `grant allows material balances beyond legacy cap`() throws {
        var homestead = PlayerHomesteadState(
            resources: [.wood: 995, .stone: 1500],
            nodeTiers: [:],
        )

        homestead.grant([
            ResourceAmount(.wood, 10),
            ResourceAmount(.stone, 5),
            ResourceAmount(.food, 3),
        ])

        try #expect(homestead.resources[.wood] == 1005)
        try #expect(homestead.resources[.stone] == 1505)
        try #expect(homestead.resources[.food] == 3)
    }

    @Test func `production preserves fractional progress between settlements`() throws {
        let start = Date(timeIntervalSince1970: 0)
        var homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 1],
            lastProductionAt: start,
        )
        let roster = PlayerRosterState.freshStart

        homestead.settleProduction(
            at: start.addingTimeInterval(12 * 60 * 60),
            roster: roster,
        )
        try #expect(abs(homestead.pendingProduction[.food, default: 0] - 0.5) < 0.0001)

        var collectingRoster = roster
        let collected = homestead.collectProduction(
            at: start.addingTimeInterval(24 * 60 * 60),
            roster: &collectingRoster,
        )
        try #expect(collected == [ResourceAmount(.food, 1)])
        try #expect(homestead.resources[.food] == 1)
        try #expect(homestead.pendingProduction.isEmpty)
    }

    @Test func `material production continues beyond legacy cap`() throws {
        let start = Date(timeIntervalSince1970: 0)
        var homestead = PlayerHomesteadState(
            resources: [.food: 998],
            nodeTiers: [.wheatField: 1],
            lastProductionAt: start,
        )
        var roster = PlayerRosterState.freshStart

        homestead.settleProduction(
            at: start.addingTimeInterval(2 * PlayerHomesteadState.secondsPerDay),
            roster: roster,
        )
        try #expect(homestead.pendingProduction[.food] == 2)
        try #expect(
            homestead.collectProduction(
                at: start.addingTimeInterval(2 * PlayerHomesteadState.secondsPerDay),
                roster: &roster,
            ) == [ResourceAmount(.food, 2)],
        )
        try #expect(homestead.resources[.food] == 1000)
    }

    @Test func `gold production collects into roster and respects gold cap`() throws {
        let start = Date(timeIntervalSince1970: 0)
        var homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wishingWell: 1],
            lastProductionAt: start,
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = PlayerRosterState.maxGoldBalance - 1

        homestead.settleProduction(
            at: start.addingTimeInterval(2 * PlayerHomesteadState.secondsPerDay),
            roster: roster,
        )
        try #expect(homestead.pendingProduction[.gold] == 1)

        let collected = homestead.collectProduction(
            at: start.addingTimeInterval(2 * PlayerHomesteadState.secondsPerDay),
            roster: &roster,
        )
        try #expect(collected == [ResourceAmount(.gold, 1)])
        try #expect(roster.gold == PlayerRosterState.maxGoldBalance)
        try #expect(homestead.pendingProduction.isEmpty)
    }

    @Test func `pending gold preview matches collected amount at cap`() throws {
        let start = Date(timeIntervalSince1970: 0)
        var homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wishingWell: 1],
            lastProductionAt: start,
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = PlayerRosterState.maxGoldBalance - 1
        let collectAt = start.addingTimeInterval(3 * PlayerHomesteadState.secondsPerDay)

        let preview = homestead.pendingProductionAmounts(at: collectAt, roster: roster)
        let collected = homestead.collectProduction(at: collectAt, roster: &roster)
        try #expect(preview == collected)
        try #expect(collected == [ResourceAmount(.gold, 1)])
        try #expect(roster.gold == PlayerRosterState.maxGoldBalance)
    }

    @Test func `next collectible date wakes at next whole unit`() throws {
        let start = Date(timeIntervalSince1970: 0)
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 1],
            lastProductionAt: start,
        )
        let roster = PlayerRosterState.freshStart

        let fromStart = try #require(homestead.nextCollectibleDate(after: start, roster: roster))
        try #expect(abs(fromStart.timeIntervalSince(start) - PlayerHomesteadState.secondsPerDay) < 0.001)

        let halfway = start.addingTimeInterval(12 * 60 * 60)
        let fromHalfway = try #require(homestead.nextCollectibleDate(after: halfway, roster: roster))
        try #expect(abs(fromHalfway.timeIntervalSince(halfway) - 12 * 60 * 60) < 0.001)
    }

    @Test func `material grant settles production before applying reward`() throws {
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
                lastProductionAt: start,
            ),
        )

        let granted = save.grantMaterials(
            [ResourceAmount(.food, 1000)],
            at: start.addingTimeInterval(PlayerHomesteadState.secondsPerDay),
        )

        try #expect(granted == [ResourceAmount(.food, 1000)])
        try #expect(save.homestead.resources[.food] == 1000)
        try #expect(save.homestead.pendingProduction[.food] == 1)
    }

    @Test func `gold grant settles production and returns actual amount`() throws {
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
                lastProductionAt: start,
            ),
        )

        let granted = save.grantGold(10, at: start.addingTimeInterval(PlayerHomesteadState.secondsPerDay))

        try #expect(granted == 3)
        try #expect(save.roster.gold == PlayerRosterState.maxGoldBalance - 1)
        try #expect(save.homestead.pendingProduction[.gold] == 1)
    }

    @Test func `canAfford and deductCost handle mixed resources and gold`() {
        var homestead = PlayerHomesteadState(resources: [.wood: 10, .iron: 5], nodeTiers: [:])
        var roster = PlayerRosterState.freshStart
        roster.gold = 50

        let cost = [
            ResourceAmount(.gold, 20),
            ResourceAmount(.wood, 4),
            ResourceAmount(.iron, 5),
        ]

        #expect(homestead.canAfford(cost: cost, roster: roster))

        // Exceeding gold
        let tooExpensiveGold = [ResourceAmount(.gold, 60)]
        #expect(!homestead.canAfford(cost: tooExpensiveGold, roster: roster))

        // Exceeding resource
        let tooExpensiveResource = [ResourceAmount(.wood, 15)]
        #expect(!homestead.canAfford(cost: tooExpensiveResource, roster: roster))

        // Successful deduction
        homestead.deductCost(cost, roster: &roster)
        #expect(roster.gold == 30)
        #expect(homestead.resources[.wood] == 6)
        #expect(homestead.resources[.iron] == 0)
    }
}
