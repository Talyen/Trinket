import Foundation

/// Shared single-value alias-migration decoding for persisted string enums.
///
/// Each conformer lists retired raw values in `aliases`; decoding resolves an
/// alias to its live case so pre-rename saves survive, and encoding always
/// writes the live raw value.
protocol AliasedRawRepresentable: RawRepresentable, Codable where RawValue == String {
    /// Retired persisted identifiers mapped to their live replacement.
    static var aliases: [String: Self] { get }
}

extension AliasedRawRepresentable {
    public static func resolving(id: String) -> Self? {
        if let aliased = aliases[id] {
            return aliased
        }
        return Self(rawValue: id)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let id = try container.decode(String.self)
        guard let value = Self.resolving(id: id) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown \(Self.self): \(id)",
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum HomesteadResource: String, CaseIterable, Codable, Hashable, Identifiable, Sendable, AliasedRawRepresentable {
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

    /// TestFlight saves written before the Crystal → Gems rename encode this
    /// resource as `"crystal"`; resolve that alias so existing balances survive.
    static let aliases: [String: Self] = ["crystal": .gems]
    public static func resolving(resourceID: String) -> Self? {
        resolving(id: resourceID)
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
public enum HomesteadNodeID: String, CaseIterable, Codable, Hashable, Identifiable, Sendable, AliasedRawRepresentable {
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

    /// Saves written before the Scriptorium → Library rename encode this
    /// node as `"scriptorium"`; resolve that alias so existing tiers survive.
    static let aliases: [String: Self] = ["scriptorium": .library]
    public static func resolving(nodeID: String) -> Self? {
        resolving(id: nodeID)
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
