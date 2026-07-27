import Foundation
import TrinketCore

/// Stable identifier for a Spire climb (player-facing name lives on `SpireDefinition.title`).
public struct SpireID: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    public let rawValue: String

    public var id: String {
        rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static let ironVein = Self("ironVein")
    public static let cinderSpire = Self("cinderSpire")
    public static let serpentHollow = Self("serpentHollow")
    public static let scarGallery = Self("scarGallery")
    public static let aureateChoir = Self("aureateChoir")
    public static let rimeVault = Self("rimeVault")
    public static let stormAnvil = Self("stormAnvil")
}

public struct SpireDefinition: Identifiable, Hashable, Sendable {
    public let id: SpireID
    public let title: String
    public let epithet: String
    public let keyword: Keyword
    public let floorCount: Int

    public init(
        id: SpireID,
        title: String,
        epithet: String,
        keyword: Keyword,
        floorCount: Int = 20
    ) {
        self.id = id
        self.title = title
        self.epithet = epithet
        self.keyword = keyword
        self.floorCount = floorCount
    }
}

public struct SpireFloor: Identifiable, Hashable, Sendable {
    public let spireID: SpireID
    public let floor: Int
    public let enemyID: String

    public var id: String {
        "\(spireID.rawValue)-floor-\(floor)"
    }

    public init(
        spireID: SpireID,
        floor: Int,
        enemyID: String
    ) {
        self.spireID = spireID
        self.floor = floor
        self.enemyID = enemyID
    }
}

public enum SpireAttunement: Equatable, Sendable {
    case ready
    case missingHeroAffinity
    case missingCompanionAffinity

    public var isReady: Bool {
        self == .ready
    }

    public var message: String {
        switch self {
        case .ready:
            "Party is attuned."
        case .missingHeroAffinity:
            "Hero needs an ability that matches this Spire."
        case .missingCompanionAffinity:
            "Companion needs an ability that matches this Spire."
        }
    }

    /// Whether a combatant's ability pool includes this Spire's keyword.
    public static func matches(_ combatant: Combatant, spire: SpireDefinition) -> Bool {
        combatant.keywordProfile.contains(spire.keyword)
    }

    /// Hub unlock: roster has at least one matching Hero and Companion.
    public static func canEnter(
        _ spire: SpireDefinition,
        heroes: [Combatant],
        companions: [Combatant]
    ) -> Bool {
        heroes.contains { matches($0, spire: spire) }
            && companions.contains { matches($0, spire: spire) }
    }

    /// v1: Hero and Companion must each have the Spire keyword in their ability pool.
    public static func evaluate(
        hero: Combatant,
        companion: Combatant,
        spire: SpireDefinition
    ) -> Self {
        if !matches(hero, spire: spire) {
            return .missingHeroAffinity
        }
        if !matches(companion, spire: spire) {
            return .missingCompanionAffinity
        }
        return .ready
    }
}
