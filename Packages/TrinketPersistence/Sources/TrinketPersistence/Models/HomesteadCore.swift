import Foundation

public enum HomesteadResource: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case wood
    case stone
    case iron
    case food
    case herbs
    case crystal
    case gold

    public var id: String {
        rawValue
    }
}

public struct ResourceAmount: Codable, Hashable, Identifiable, Sendable {
    public let resource: HomesteadResource
    public let quantity: Int

    public var id: HomesteadResource {
        resource
    }

    public init(_ resource: HomesteadResource, _ quantity: Int) {
        self.resource = resource
        self.quantity = quantity
    }
}

public enum HomesteadNodeID: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case wheatField
    case herbGarden
    case chickenCoop
    case pasture
    case blacksmithForge
    case alchemyLab
    case crystalGarden
    case runesmithWorkshop
    case wishingWell

    public var id: String {
        rawValue
    }
}

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
