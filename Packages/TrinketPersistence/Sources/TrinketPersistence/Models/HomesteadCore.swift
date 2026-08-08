import Foundation
import TrinketContent
import TrinketCore

public struct PlayerHomesteadState: Codable, Equatable, Hashable, Sendable {
    public var resources: [HomesteadResource: Int]
    public var nodeTiers: [HomesteadNodeID: Int]
    public var pendingProduction: [HomesteadResource: Double]
    public var lastProductionAt: Date

    /// Soft cap for stored homestead materials (gold is roster-owned).
    public static let maxMaterialBalance = 999
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
            lastProductionAt: deterministicSeedProductionDate
        )
    }

    /// Development-only seed used by Options' Unlock All action.
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
        lastProductionAt: Date
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
            let current = resources[reward.resource, default: 0]
            let pendingCapacity = Self.maxMaterialBalance
                - Int(ceil(pendingProduction[reward.resource, default: 0]))
            let available = max(0, pendingCapacity - current)
            resources[reward.resource] = min(current + reward.quantity, current + available)
        }
    }

    /// Amounts that `grant` would actually add after the material cap (zeros omitted).
    public func receivableAmounts(from rewards: [ResourceAmount]) -> [ResourceAmount] {
        rewards.compactMap { reward in
            guard reward.resource != .gold, reward.quantity > 0 else { return nil }
            let current = resources[reward.resource, default: 0]
            let pendingCapacity = Self.maxMaterialBalance
                - Int(ceil(pendingProduction[reward.resource, default: 0]))
            let granted = min(current + reward.quantity, current + max(0, pendingCapacity - current)) - current
            guard granted > 0 else { return nil }
            return ResourceAmount(reward.resource, granted)
        }
    }

    public static func clampedMaterialBalance(_ quantity: Int) -> Int {
        min(max(quantity, 0), maxMaterialBalance)
    }

    public func pendingProductionAmounts(
        at date: Date,
        roster: PlayerRosterState
    ) -> [ResourceAmount] {
        var projected = self
        projected.settleProduction(at: date, roster: roster)
        return projected.pendingProduction
            .compactMap { resource, amount in
                let balance = Double(projected.balance(for: resource, roster: roster))
                let maximum = resource == .gold
                    ? PlayerRosterState.maxGoldBalance
                    : Self.maxMaterialBalance
                let quantity = min(Int(amount.rounded(.down)), max(0, maximum - Int(balance)))
                guard quantity > 0 else { return nil }
                return ResourceAmount(resource, quantity)
            }
            .sorted { $0.resource.rawValue < $1.resource.rawValue }
    }

    @discardableResult
    public mutating func collectProduction(
        at date: Date,
        roster: inout PlayerRosterState
    ) -> [ResourceAmount] {
        settleProduction(at: date, roster: roster)

        let collected = pendingProduction
            .compactMap { resource, amount -> ResourceAmount? in
                let balance = balance(for: resource, roster: roster)
                let maximum = resource == .gold
                    ? PlayerRosterState.maxGoldBalance
                    : Self.maxMaterialBalance
                let quantity = min(Int(amount.rounded(.down)), max(0, maximum - balance))
                guard quantity > 0 else { return nil }
                return ResourceAmount(resource, quantity)
            }
            .sorted { $0.resource.rawValue < $1.resource.rawValue }

        for amount in collected {
            let quantity: Int
            if amount.resource == .gold {
                let current = roster.gold
                quantity = min(amount.quantity, PlayerRosterState.maxGoldBalance - current)
                roster.grantGold(quantity)
            } else {
                let current = resources[amount.resource, default: 0]
                quantity = min(amount.quantity, Self.maxMaterialBalance - current)
                resources[amount.resource] = current + quantity
            }
            pendingProduction[amount.resource, default: 0] -= Double(quantity)
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

            let current = Double(balance(for: production.resource, roster: roster))
            let pending = pendingProduction[production.resource, default: 0]
            let maximum = production.resource == .gold
                ? Double(PlayerRosterState.maxGoldBalance)
                : Double(Self.maxMaterialBalance)
            let capacity = maximum - current - pending
            guard capacity > 0 else { continue }

            let generated = min(
                capacity,
                Double(production.quantity) * elapsed / Self.secondsPerDay
            )
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
