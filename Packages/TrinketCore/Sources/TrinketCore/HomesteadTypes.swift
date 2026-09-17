import Foundation

public enum HomesteadResource: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case wood
    case stone
    case iron
    case food
    case herbs
    case hide
    case gems
    case gold

    public var id: String {
        rawValue
    }

    /// Maps a persisted resource identifier to a live case.
    /// TestFlight saves written before the Crystal → Gems rename encode this
    /// resource as `"crystal"`; resolve that alias so existing balances survive.
    public static func resolving(resourceID: String) -> Self? {
        if resourceID == "crystal" {
            return .gems
        }
        return Self(rawValue: resourceID)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let resourceID = try container.decode(String.self)
        guard let resource = Self.resolving(resourceID: resourceID) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown HomesteadResource: \(resourceID)",
            )
        }
        self = resource
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
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
// Node IDs are stored in saves; never rename a raw value without a migration.
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
    case transmutationCrucible = "transmutationCrucible"
    case mycologyCellar = "mycologyCellar"
    case sparringGrounds = "sparringGrounds"
    case archeryRange = "archeryRange"
    case library = "library"
    case leylineEnergy = "leylineEnergy"

    public var id: String {
        rawValue
    }

    /// Maps a persisted node identifier to a live case.
    /// Saves written before the Scriptorium → Library rename encode this
    /// node as `"scriptorium"`; resolve that alias so existing tiers survive.
    public static func resolving(nodeID: String) -> Self? {
        if nodeID == "scriptorium" {
            return .library
        }
        return Self(rawValue: nodeID)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let nodeID = try container.decode(String.self)
        guard let node = Self.resolving(nodeID: nodeID) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown HomesteadNodeID: \(nodeID)",
            )
        }
        self = node
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// swiftformat:enable redundantRawValues

public enum HomesteadNodeCategory: String, CaseIterable, Hashable, Identifiable, Codable, Sendable {
    case farming = "Farming"
    case crafting = "Crafting"
    case alchemy = "Alchemy"
    case training = "Training"
    case arcana = "Arcana"

    public var id: String {
        rawValue
    }
}
