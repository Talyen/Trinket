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
    case culinaryArts
    case blacksmithForge
    case woolTailoring
    case alchemyLab
    case botanicalDistillation
    case crystalGarden
    case runesmithWorkshop
    case hunterLodge
    case agilityTraining
    case detectMagic
    case wishingWell

    public var id: String {
        rawValue
    }
}

public enum HomesteadTint: String, CaseIterable, Codable, Hashable, Sendable {
    case orange
    case green
    case yellow
    case mint
    case cyan
    case indigo
    case blue
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
