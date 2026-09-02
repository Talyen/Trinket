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

// swiftformat:disable redundantRawValues - persisted node identifiers must remain explicit
// swiftlint:disable redundant_string_enum_value - persisted node identifiers must remain explicit
public enum HomesteadNodeID: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case wheatField = "wheatField"
    case herbGarden = "herbGarden"
    case chickenCoop = "chickenCoop"
    case pasture = "pasture"
    case culinaryArts = "culinaryArts"
    case blacksmithForge = "blacksmithForge"
    case woolTailoring = "woolTailoring"
    case alchemyLab = "alchemyLab"
    case crystalGarden = "crystalGarden"
    case runesmithWorkshop = "runesmithWorkshop"
    case hunterLodge = "hunterLodge"
    case agilityTraining = "agilityTraining"
    case moonlitSanctum = "moonlitSanctum"
    case wishingWell = "wishingWell"

    public var id: String {
        rawValue
    }
}

// swiftlint:enable redundant_string_enum_value
// swiftformat:enable redundantRawValues

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
