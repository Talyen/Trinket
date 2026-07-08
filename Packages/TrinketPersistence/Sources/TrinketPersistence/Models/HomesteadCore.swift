import Foundation
import TrinketContent
import TrinketCore

public struct PlayerHomesteadState: Codable, Equatable, Hashable, Sendable {
    public var resources: [HomesteadResource: Int]
    public var nodeTiers: [HomesteadNodeID: Int]

    public static var freshStart: PlayerHomesteadState {
        PlayerHomesteadState(resources: [:], nodeTiers: [:])
    }

    public static var testSeed: PlayerHomesteadState {
        PlayerHomesteadState(
            resources: [
                .wood: 40,
                .stone: 28,
                .iron: 12,
                .food: 20,
                .herbs: 14,
                .crystal: 4
            ],
            nodeTiers: [
                .wheatField: 1,
                .herbGarden: 1,
                .chickenCoop: 1
            ]
        )
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

    public func adjustedMaterialRewards(_ rewards: [ResourceAmount]) -> [ResourceAmount] {
        var combined: [HomesteadResource: Int] = [:]
        for reward in rewards where reward.resource != .gold {
            combined[reward.resource, default: 0] += adjustedQuantity(for: reward)
        }
        return HomesteadResource.allCases.compactMap { resource in
            guard resource != .gold, let quantity = combined[resource], quantity > 0 else { return nil }
            return ResourceAmount(resource, quantity)
        }
    }

    public mutating func grant(_ rewards: [ResourceAmount]) {
        for reward in rewards where reward.resource != .gold && reward.quantity > 0 {
            resources[reward.resource, default: 0] += reward.quantity
        }
    }

    private func adjustedQuantity(for reward: ResourceAmount) -> Int {
        var quantity = reward.quantity
        if tier(for: .wheatField) >= 3 || tier(for: .wishingWell) >= 2 {
            quantity += 1
        }
        if reward.resource == .food {
            if tier(for: .wheatField) >= 2 { quantity += 1 }
            if tier(for: .chickenCoop) >= 2 { quantity += 1 }
            if tier(for: .pasture) >= 2 { quantity += 1 }
        } else if reward.resource == .herbs, tier(for: .herbGarden) >= 2 {
            quantity += 1
        } else if reward.resource == .iron, tier(for: .blacksmithForge) >= 2 {
            quantity += 1
        } else if reward.resource == .crystal {
            if tier(for: .crystalGarden) >= 2 {
                quantity += tier(for: .runesmithWorkshop) >= 2 ? 2 : 1
            }
        }
        return quantity
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

public extension PlayerHomesteadState {
    var current: PlayerHomesteadState {
        get { self }
        set { self = newValue }
    }
}
