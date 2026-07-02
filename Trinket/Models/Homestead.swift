import SwiftUI

enum HomesteadResource: String, CaseIterable, Codable, Hashable, Identifiable {
    case wood
    case stone
    case iron
    case food
    case herbs
    case crystal
    case gold

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .wood: return "Wood"
        case .stone: return "Stone"
        case .iron: return "Iron"
        case .food: return "Food"
        case .herbs: return "Herbs"
        case .crystal: return "Crystal"
        case .gold: return "Gold"
        }
    }

    var symbolName: String {
        switch self {
        case .wood: return "tree.fill"
        case .stone: return "mountain.2.fill"
        case .iron: return "hammer.fill"
        case .food: return "carrot.fill"
        case .herbs: return "leaf.fill"
        case .crystal: return "sparkles"
        case .gold: return "dollarsign.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .wood: return .brown
        case .stone: return Color(red: 0.58, green: 0.54, blue: 0.48)
        case .iron: return Color(red: 0.30, green: 0.39, blue: 0.48)
        case .food: return .orange
        case .herbs: return .green
        case .crystal: return .blue
        case .gold: return Keyword.gold.visualStyle.color
        }
    }
}

struct ResourceAmount: Codable, Hashable, Identifiable {
    let resource: HomesteadResource
    let quantity: Int

    var id: HomesteadResource {
        resource
    }

    init(_ resource: HomesteadResource, _ quantity: Int) {
        self.resource = resource
        self.quantity = quantity
    }
}

enum HomesteadNodeID: String, CaseIterable, Codable, Hashable, Identifiable {
    case wheatField
    case herbGarden
    case chickenCoop
    case pasture
    case blacksmithForge
    case alchemyLab
    case crystalGarden
    case runesmithWorkshop
    case wishingWell

    var id: String {
        rawValue
    }
}

struct HomesteadNodeRequirement: Hashable {
    let nodeID: HomesteadNodeID
    let minimumTier: Int

    init(_ nodeID: HomesteadNodeID, tier: Int = 1) {
        self.nodeID = nodeID
        minimumTier = tier
    }
}

enum HomesteadNodeCategory: String, CaseIterable, Hashable, Identifiable {
    case farming = "Farming"
    case crafting = "Crafting"
    case research = "Research"

    var id: String {
        rawValue
    }
}

struct HomesteadBonus: Hashable {
    let title: String
    let description: String
}

struct HomesteadNodeTier: Hashable {
    let tier: Int
    let cost: [ResourceAmount]
    let bonus: HomesteadBonus
}

struct HomesteadNodeDefinition: Identifiable, Hashable {
    let id: HomesteadNodeID
    let title: String
    let summary: String
    let symbolName: String
    let tint: Color
    let category: HomesteadNodeCategory
    let prerequisites: [HomesteadNodeRequirement]
    let tiers: [HomesteadNodeTier]

    var maxTier: Int {
        tiers.map(\.tier).max() ?? 0
    }

    func tier(_ value: Int) -> HomesteadNodeTier? {
        tiers.first { $0.tier == value }
    }
}

struct PlayerHomesteadState: Codable, Equatable, Hashable {
    var resources: [HomesteadResource: Int]
    var nodeTiers: [HomesteadNodeID: Int]

    static var freshStart: PlayerHomesteadState {
        PlayerHomesteadState(resources: [:], nodeTiers: [:])
    }

    static var testSeed: PlayerHomesteadState {
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

    func balance(for resource: HomesteadResource, roster: PlayerRosterState) -> Int {
        if resource == .gold {
            return roster.gold
        }
        return resources[resource, default: 0]
    }

    func tier(for nodeID: HomesteadNodeID) -> Int {
        nodeTiers[nodeID, default: 0]
    }

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

    func adjustedMaterialRewards(_ rewards: [ResourceAmount]) -> [ResourceAmount] {
        var combined: [HomesteadResource: Int] = [:]
        for reward in rewards where reward.resource != .gold {
            combined[reward.resource, default: 0] += adjustedQuantity(for: reward)
        }
        return HomesteadResource.allCases.compactMap { resource in
            guard resource != .gold, let quantity = combined[resource], quantity > 0 else { return nil }
            return ResourceAmount(resource, quantity)
        }
    }

    mutating func grant(_ rewards: [ResourceAmount]) {
        for reward in rewards where reward.resource != .gold && reward.quantity > 0 {
            resources[reward.resource, default: 0] += reward.quantity
        }
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

    private func adjustedQuantity(for reward: ResourceAmount) -> Int {
        var quantity = reward.quantity
        if tier(for: .wheatField) >= 3 || tier(for: .wishingWell) >= 2 {
            quantity += 1
        }
        switch reward.resource {
        case .food where tier(for: .wheatField) >= 2:
            quantity += 1
        case .food where tier(for: .chickenCoop) >= 2:
            quantity += 1
        case .food where tier(for: .pasture) >= 2:
            quantity += 1
        case .herbs where tier(for: .herbGarden) >= 2:
            quantity += 1
        case .iron where tier(for: .blacksmithForge) >= 2:
            quantity += 1
        case .crystal where tier(for: .crystalGarden) >= 2:
            quantity += tier(for: .runesmithWorkshop) >= 2 ? 2 : 1
        default:
            break
        }
        return quantity
    }
}
