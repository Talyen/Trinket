import Foundation
import TrinketCore

/// Stable identifier for an Aspect climb (player-facing name lives on `AspectDefinition.title`).
public struct AspectID: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
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

    public static let ironVein = AspectID("ironVein")
    public static let cinderSpire = AspectID("cinderSpire")
    public static let serpentHollow = AspectID("serpentHollow")
    public static let scarGallery = AspectID("scarGallery")
    public static let aureateChoir = AspectID("aureateChoir")
    public static let rimeVault = AspectID("rimeVault")
    public static let stormAnvil = AspectID("stormAnvil")
}

public struct AspectDefinition: Identifiable, Hashable, Sendable {
    public let id: AspectID
    public let title: String
    public let epithet: String
    public let keyword: Keyword
    public let floorCount: Int

    public init(
        id: AspectID,
        title: String,
        epithet: String,
        keyword: Keyword,
        floorCount: Int = 10
    ) {
        self.id = id
        self.title = title
        self.epithet = epithet
        self.keyword = keyword
        self.floorCount = floorCount
    }
}

public struct AspectFloor: Identifiable, Hashable, Sendable {
    public let aspectID: AspectID
    public let floor: Int
    public let enemyID: String

    public var id: String {
        "\(aspectID.rawValue)-floor-\(floor)"
    }

    public init(
        aspectID: AspectID,
        floor: Int,
        enemyID: String
    ) {
        self.aspectID = aspectID
        self.floor = floor
        self.enemyID = enemyID
    }
}

public enum AspectAttunement: Equatable, Sendable {
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
            "Hero needs an ability that matches this Aspect."
        case .missingCompanionAffinity:
            "Companion needs an ability that matches this Aspect."
        }
    }

    /// v1: Hero and Companion must each have the Aspect keyword in their ability pool.
    public static func evaluate(
        hero: Combatant,
        companion: Combatant,
        aspect: AspectDefinition
    ) -> AspectAttunement {
        if !hero.keywordProfile.contains(aspect.keyword) {
            return .missingHeroAffinity
        }
        if !companion.keywordProfile.contains(aspect.keyword) {
            return .missingCompanionAffinity
        }
        return .ready
    }
}
