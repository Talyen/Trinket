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
