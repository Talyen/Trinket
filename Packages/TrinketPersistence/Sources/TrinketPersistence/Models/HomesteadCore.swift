import Foundation
import TrinketContent
import TrinketCore

public struct PlayerHomesteadState: Codable, Equatable, Hashable, Sendable {
    public var resources: [HomesteadResource: Int]
    public var nodeTiers: [HomesteadNodeID: Int]

    /// Soft cap for stored homestead materials (gold is roster-owned).
    public static let maxMaterialBalance = 999

    public static var freshStart: Self {
        Self(resources: [:], nodeTiers: [:])
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
            ]
        )
    }

    /// Development-only seed used by Options' Unlock All action.
    public static var developerMaxed: Self {
        var state = testSeed
        for resource in HomesteadResource.allCases where resource != .gold {
            state.resources[resource] = maxMaterialBalance
        }
        for nodeID in HomesteadNodeID.allCases {
            state.nodeTiers[nodeID] = HomesteadNodeCatalog.maxTierByNodeID[nodeID, default: 3]
        }
        return state
    }

    public init(resources: [HomesteadResource: Int], nodeTiers: [HomesteadNodeID: Int]) {
        self.resources = resources
        self.nodeTiers = nodeTiers
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
            resources[reward.resource] = min(current + reward.quantity, Self.maxMaterialBalance)
        }
    }

    /// Amounts that `grant` would actually add after the material cap (zeros omitted).
    public func receivableAmounts(from rewards: [ResourceAmount]) -> [ResourceAmount] {
        rewards.compactMap { reward in
            guard reward.resource != .gold, reward.quantity > 0 else { return nil }
            let current = resources[reward.resource, default: 0]
            let granted = min(current + reward.quantity, Self.maxMaterialBalance) - current
            guard granted > 0 else { return nil }
            return ResourceAmount(reward.resource, granted)
        }
    }

    public static func clampedMaterialBalance(_ quantity: Int) -> Int {
        min(max(quantity, 0), maxMaterialBalance)
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
