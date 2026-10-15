import Foundation
import Testing
import TrinketContent
import TrinketCore

struct HomesteadStateTests {
    @Test func `collecting maximum material credit retains the last owed unit across reload`() throws {
        let date = Date(timeIntervalSince1970: 1000)
        var state = PlayerHomesteadState(
            resources: [:], nodeTiers: [:],
            pendingProduction: [.stone: Double(Int.max)], lastProductionAt: date,
        )
        var gold = 0

        #expect(state.collectProduction(at: date, gold: &gold) == [ResourceAmount(.stone, Int.max)])
        #expect(state.resources[.stone] == Int.max)
        #expect(state.pendingProduction[.stone] == 1)
        state = try JSONDecoder().decode(PlayerHomesteadState.self, from: JSONEncoder().encode(state))
        state.deductCost([ResourceAmount(.stone, 1)], gold: &gold)
        #expect(state.collectProduction(at: date, gold: &gold) == [ResourceAmount(.stone, 1)])
        #expect(state.resources[.stone] == Int.max)
        #expect(state.pendingProduction.isEmpty)
    }

    @Test(arguments: [false, true])
    func `extreme production credit remains collectible and survives reload`(overflowElapsed: Bool) throws {
        let start = Date(timeIntervalSinceReferenceDate: overflowElapsed ? -Double.greatestFiniteMagnitude : 0)
        let end = Date(timeIntervalSinceReferenceDate: Double.greatestFiniteMagnitude)
        var state = PlayerHomesteadState(
            resources: [:], nodeTiers: [.wheatField: 3],
            pendingProduction: [.food: Double.greatestFiniteMagnitude], lastProductionAt: start,
        )
        state = try JSONDecoder().decode(PlayerHomesteadState.self, from: JSONEncoder().encode(state))

        state.settleProduction(at: end, gold: 0)
        let reloaded = try JSONDecoder().decode(PlayerHomesteadState.self, from: JSONEncoder().encode(state))
        #expect(reloaded.pendingProduction[.food] == Double.greatestFiniteMagnitude)
        #expect(reloaded.pendingProductionAmounts(at: end, gold: 0) == [ResourceAmount(.food, Int.max)])
    }

    @Test func `crystal production survives reload and collects both resources once`() throws {
        let start = Date(timeIntervalSince1970: 1000)
        var state = PlayerHomesteadState(resources: [:], nodeTiers: [.crystalGarden: 4], lastProductionAt: start)
        var gold = 0
        state.settleProduction(at: start.addingTimeInterval(43200), gold: gold)
        state = try JSONDecoder().decode(PlayerHomesteadState.self, from: JSONEncoder().encode(state))
        let end = start.addingTimeInterval(86400)
        let first = state.collectProduction(at: end, gold: &gold)
        #expect(Set(first) == Set([ResourceAmount(.gems, 4), ResourceAmount(.stone, 4)]))
        #expect(state.collectProduction(at: end, gold: &gold).isEmpty)
    }

    @Test(arguments: GameContent.homesteadNodes)
    func `any node can be the first building when its materials are available`(definition: HomesteadNodeDefinition) throws {
        let tier = try #require(definition.tier(1))
        var homestead = PlayerHomesteadState.freshStart
        var gold = 0
        for amount in tier.cost {
            if amount.resource == .gold {
                gold = amount.quantity
            } else {
                homestead.resources[amount.resource] = amount.quantity
            }
        }
        #expect(homestead.buildOrUpgrade(definition, gold: &gold))
        #expect(homestead.nodeTiers == [definition.id: 1])
        for amount in tier.cost {
            #expect(homestead.balance(for: amount.resource, gold: gold) == 0)
        }
    }

    @Test func `effects replace lower tiers instead of stacking`() throws {
        let tier1 = HomesteadEffects.from(nodeTiers: [.wheatField: 1])
        let tier3 = HomesteadEffects.from(nodeTiers: [.wheatField: 3])

        try #expect(tier1.heroModifiers == [.maximumHealthPercent(0.1)])
        try #expect(tier1.companionModifiers.isEmpty)
        try #expect(tier3.heroModifiers == [.maximumHealthPercent(0.3)])
        try #expect(tier3.companionModifiers.isEmpty)
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

    @Test func `material collection leaves overflow available after spending`() {
        let date = Date(timeIntervalSince1970: 1000)
        var homestead = PlayerHomesteadState(
            resources: [.stone: Int.max - 2],
            nodeTiers: [:],
            pendingProduction: [.stone: 12.75],
            lastProductionAt: date,
        )
        var gold = 0

        #expect(homestead.pendingProductionAmounts(at: date, gold: gold) == [ResourceAmount(.stone, 2)])
        #expect(homestead.collectProduction(at: date, gold: &gold) == [ResourceAmount(.stone, 2)])
        #expect(homestead.resources[.stone] == Int.max)
        #expect(homestead.pendingProduction[.stone] == 10.75)
        #expect(homestead.pendingProductionAmounts(at: date, gold: gold).isEmpty)

        homestead.deductCost([ResourceAmount(.stone, 4)], gold: &gold)
        #expect(homestead.collectProduction(at: date, gold: &gold) == [ResourceAmount(.stone, 4)])
        #expect(homestead.resources[.stone] == Int.max)
        #expect(homestead.pendingProduction[.stone] == 6.75)
    }

    @Test func `production preserves fractional progress between settlements`() throws {
        let start = Date(timeIntervalSince1970: 0)
        var homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 1],
            lastProductionAt: start,
        )
        let gold = 0

        homestead.settleProduction(
            at: start.addingTimeInterval(12 * 60 * 60),
            gold: gold,
        )
        try #expect(abs(homestead.pendingProduction[.food, default: 0] - 0.5) < 0.0001)

        var collectingGold = gold
        let collected = homestead.collectProduction(
            at: start.addingTimeInterval(24 * 60 * 60),
            gold: &collectingGold,
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
        var gold = 0

        homestead.settleProduction(
            at: start.addingTimeInterval(2 * PlayerHomesteadState.secondsPerDay),
            gold: gold,
        )
        try #expect(homestead.pendingProduction[.food] == 2)
        try #expect(
            homestead.collectProduction(
                at: start.addingTimeInterval(2 * PlayerHomesteadState.secondsPerDay),
                gold: &gold,
            ) == [ResourceAmount(.food, 2)],
        )
        try #expect(homestead.resources[.food] == 1000)
    }

    @Test func `gold production collects into wallet and respects gold cap`() throws {
        let start = Date(timeIntervalSince1970: 0)
        var homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wishingWell: 1],
            lastProductionAt: start,
        )
        var gold = GoldBalance.maximum - 1

        homestead.settleProduction(
            at: start.addingTimeInterval(2 * PlayerHomesteadState.secondsPerDay),
            gold: gold,
        )
        try #expect(homestead.pendingProduction[.gold] == 1)

        let collectAt = start.addingTimeInterval(2 * PlayerHomesteadState.secondsPerDay)
        let preview = homestead.pendingProductionAmounts(at: collectAt, gold: gold)
        let collected = homestead.collectProduction(at: collectAt, gold: &gold)
        try #expect(preview == collected)
        try #expect(collected == [ResourceAmount(.gold, 1)])
        try #expect(gold == GoldBalance.maximum)
        try #expect(homestead.pendingProduction.isEmpty)
    }

    @Test func `full material storage does not schedule impossible collection wakeups`() throws {
        let date = Date(timeIntervalSince1970: 1000)
        var state = PlayerHomesteadState(
            resources: [.food: Int.max], nodeTiers: [.wheatField: 1], lastProductionAt: date,
        )
        #expect(state.nextCollectibleDate(after: date, gold: 0) == nil)
        var gold = 0
        state.deductCost([ResourceAmount(.food, 1)], gold: &gold)
        #expect(try #require(state.nextCollectibleDate(after: date, gold: gold)) > date)
    }

    @Test func `next collectible date wakes at next whole unit`() throws {
        let start = Date(timeIntervalSince1970: 0)
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 1],
            lastProductionAt: start,
        )
        let gold = 0

        let fromStart = try #require(homestead.nextCollectibleDate(after: start, gold: gold))
        try #expect(abs(fromStart.timeIntervalSince(start) - PlayerHomesteadState.secondsPerDay) < 0.001)

        let halfway = start.addingTimeInterval(12 * 60 * 60)
        let fromHalfway = try #require(homestead.nextCollectibleDate(after: halfway, gold: gold))
        try #expect(abs(fromHalfway.timeIntervalSince(halfway) - 12 * 60 * 60) < 0.001)
    }

    @Test func `canAfford and deductCost handle mixed resources and gold`() {
        var homestead = PlayerHomesteadState(resources: [.wood: 10, .iron: 5], nodeTiers: [:])
        var gold = 50

        let cost = [
            ResourceAmount(.gold, 20),
            ResourceAmount(.wood, 4),
            ResourceAmount(.iron, 5),
        ]

        #expect(homestead.canAfford(cost: cost, gold: gold))

        // Exceeding gold
        let tooExpensiveGold = [ResourceAmount(.gold, 60)]
        #expect(!homestead.canAfford(cost: tooExpensiveGold, gold: gold))

        // Exceeding resource
        let tooExpensiveResource = [ResourceAmount(.wood, 15)]
        #expect(!homestead.canAfford(cost: tooExpensiveResource, gold: gold))

        // Successful deduction
        homestead.deductCost(cost, gold: &gold)
        #expect(gold == 30)
        #expect(homestead.resources[.wood] == 6)
        #expect(homestead.resources[.iron] == 0)
    }
}
