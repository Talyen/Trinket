import Foundation

public enum HomesteadResource: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case wood
    case stone
    case iron
    case food
    case herbs
    case hide
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
    case culinaryArts
    case blacksmithForge
    case woolTailoring
    case alchemyLab
    case crystalGarden
    case runesmithWorkshop
    case hunterLodge
    case agilityTraining
    case moonlitSanctum
    case wishingWell

    public var id: String {
        rawValue
    }
}

public enum HomesteadNodeCategory: String, CaseIterable, Hashable, Identifiable, Sendable {
    case farming = "Farming"
    case crafting = "Crafting"
    case alchemy = "Alchemy"
    case training = "Training"
    case arcana = "Arcana"

    public var id: String {
        rawValue
    }
}
