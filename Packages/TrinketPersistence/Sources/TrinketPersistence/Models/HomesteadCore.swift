import Foundation
import TrinketContent
import TrinketCore

public struct PlayerHomesteadState: Equatable, Hashable, Sendable {
    public var resources: [HomesteadResource: Int]
    public var nodeTiers: [HomesteadNodeID: Int]
    public var pendingProduction: [HomesteadResource: Double]
    public var lastProductionAt: Date

    public static let secondsPerDay: TimeInterval = 86400.0
    private static let deterministicSeedProductionDate = Date(timeIntervalSince1970: 2000000000)

    public static var freshStart: Self {
        Self(resources: [:], nodeTiers: [:], lastProductionAt: Date(timeIntervalSince1970: 0))
    }

    public static var testSeed: Self {
        Self(
            resources: [
                .wood: 40,
                .stone: 28,
                .iron: 12,
                .food: 20,
                .herbs: 14,
                .hide: 10,
                .crystal: 4,
            ],
            nodeTiers: [
                .wheatField: 1,
                .herbGarden: 1,
                .chickenCoop: 1,
            ],
            lastProductionAt: deterministicSeedProductionDate,
        )
    }

    public static var developerMaxed: Self {
        var state = testSeed
        for resource in HomesteadResource.allCases where resource != .gold {
            state.resources[resource] = 900
        }
        for nodeID in HomesteadNodeID.allCases {
            let maxTier = HomesteadNodeCatalog.maxTierByNodeID[nodeID, default: 3]
            state.nodeTiers[nodeID] = max(0, maxTier - 1)
        }
        state.pendingProduction = [
            .food: 10,
            .herbs: 10,
            .crystal: 10,
            .hide: 10,
            .gold: 10,
        ]
        state.lastProductionAt = Date()
        return state
    }

    public init(resources: [HomesteadResource: Int], nodeTiers: [HomesteadNodeID: Int]) {
        self.init(resources: resources, nodeTiers: nodeTiers, lastProductionAt: Date())
    }

    public init(
        resources: [HomesteadResource: Int],
        nodeTiers: [HomesteadNodeID: Int],
        pendingProduction: [HomesteadResource: Double] = [:],
        lastProductionAt: Date,
    ) {
        self.resources = resources
        self.nodeTiers = nodeTiers
        self.pendingProduction = pendingProduction
        self.lastProductionAt = lastProductionAt
    }

    public func balance(for resource: HomesteadResource, roster: PlayerRosterState) -> Int {
        if resource == .gold {
            return roster.gold
        }
        return resources[resource, default: 0]
    }

    public func tier(for nodeID: HomesteadNodeID) -> Int {
        nodeTiers[nodeID, default: 0]
    }

    public var effects: HomesteadEffects {
        HomesteadEffects.from(nodeTiers: nodeTiers)
    }

    public mutating func grant(_ rewards: [ResourceAmount]) {
        for reward in rewards where reward.resource != .gold && reward.quantity > 0 {
            resources[reward.resource, default: 0] += reward.quantity
        }
    }

    public func pendingProductionAmounts(
        at date: Date,
        roster: PlayerRosterState,
    ) -> [ResourceAmount] {
        var projected = self
        projected.settleProduction(at: date, roster: roster)
        return projected.pendingProduction
            .compactMap { resource, amount in
                let quantity = projected.collectibleQuantity(
                    for: resource,
                    pending: amount,
                    roster: roster,
                )
                guard quantity > 0 else { return nil }
                return ResourceAmount(resource, quantity)
            }
            .sorted { $0.resource.rawValue < $1.resource.rawValue }
    }

    public func nextCollectibleDate(after date: Date, roster: PlayerRosterState) -> Date? {
        var projected = self
        projected.settleProduction(at: date, roster: roster)

        var rates: [HomesteadResource: Double] = [:]
        for nodeID in HomesteadNodeID.allCases {
            let activeTier = projected.tier(for: nodeID)
            guard activeTier > 0,
                  let definition = GameContent.homesteadNode(matching: nodeID),
                  let production = definition.tier(activeTier)?.production,
                  production.quantity > 0
            else { continue }
            rates[production.resource, default: 0] += Double(production.quantity) / Self.secondsPerDay
        }

        var soonest: TimeInterval?
        for (resource, rate) in rates where rate > 0 {
            let pending = projected.pendingProduction[resource, default: 0]
            if resource == .gold {
                let capacity = Double(PlayerRosterState.maxGoldBalance)
                    - Double(projected.balance(for: .gold, roster: roster))
                guard pending < capacity else { continue }
            }
            let remaining = floor(pending) + 1 - pending
            let seconds = remaining / rate
            guard seconds.isFinite, seconds > 0 else { continue }
            soonest = min(soonest ?? seconds, seconds)
        }
        return soonest.map { date.addingTimeInterval($0) }
    }

    func collectibleQuantity(
        for resource: HomesteadResource,
        pending amount: Double,
        roster: PlayerRosterState,
    ) -> Int {
        let available = Int(amount.rounded(.down))
        guard available > 0 else { return 0 }
        if resource == .gold {
            return min(
                available,
                max(0, PlayerRosterState.maxGoldBalance - balance(for: .gold, roster: roster)),
            )
        }
        return available
    }

    @discardableResult
    public mutating func collectProduction(
        at date: Date,
        roster: inout PlayerRosterState,
    ) -> [ResourceAmount] {
        settleProduction(at: date, roster: roster)

        let collected = pendingProduction
            .compactMap { resource, amount -> ResourceAmount? in
                let quantity = collectibleQuantity(for: resource, pending: amount, roster: roster)
                guard quantity > 0 else { return nil }
                return ResourceAmount(resource, quantity)
            }
            .sorted { $0.resource.rawValue < $1.resource.rawValue }

        for amount in collected {
            if amount.resource == .gold {
                roster.grantGold(amount.quantity)
            } else {
                resources[amount.resource, default: 0] += amount.quantity
            }
            pendingProduction[amount.resource, default: 0] -= Double(amount.quantity)
        }
        pendingProduction = pendingProduction.filter { $0.value > 0 }
        return collected
    }

    public mutating func settleProduction(at date: Date, roster: PlayerRosterState) {
        guard date >= lastProductionAt else { return }
        let elapsed = date.timeIntervalSince(lastProductionAt)
        guard elapsed > 0 else {
            lastProductionAt = date
            return
        }

        for nodeID in HomesteadNodeID.allCases {
            let activeTier = tier(for: nodeID)
            guard activeTier > 0,
                  let definition = GameContent.homesteadNode(matching: nodeID),
                  let production = definition.tier(activeTier)?.production,
                  production.quantity > 0
            else { continue }

            let pending = pendingProduction[production.resource, default: 0]
            let generated = Double(production.quantity) * elapsed / Self.secondsPerDay
            if production.resource == .gold {
                let capacity = Double(PlayerRosterState.maxGoldBalance)
                    - Double(balance(for: .gold, roster: roster))
                    - pending
                guard capacity > 0 else { continue }
                pendingProduction[.gold] = pending + min(capacity, generated)
                continue
            }
            pendingProduction[production.resource] = pending + generated
        }
        lastProductionAt = date
    }
}

public extension PlayerHomesteadState {
    func isUnlocked(_ definition: HomesteadNodeDefinition) -> Bool {
        definition.prerequisites.allSatisfy { tier(for: $0.nodeID) >= $0.minimumTier }
    }

    func nextTier(for definition: HomesteadNodeDefinition) -> HomesteadNodeTier? {
        definition.tier(tier(for: definition.id) + 1)
    }

    func canAfford(_ tier: HomesteadNodeTier, roster: PlayerRosterState) -> Bool {
        tier.cost.allSatisfy { balance(for: $0.resource, roster: roster) >= $0.quantity }
    }

    func isComplete(_ definition: HomesteadNodeDefinition) -> Bool {
        tier(for: definition.id) >= definition.maxTier
    }

    mutating func buildOrUpgrade(_ definition: HomesteadNodeDefinition, roster: inout PlayerRosterState) -> Bool {
        guard isUnlocked(definition),
              let tier = nextTier(for: definition),
              canAfford(tier, roster: roster)
        else { return false }

        for amount in tier.cost {
            if amount.resource == .gold {
                roster.gold -= amount.quantity
            } else {
                resources[amount.resource, default: 0] -= amount.quantity
            }
        }
        nodeTiers[definition.id, default: 0] += 1
        return true
    }
}
