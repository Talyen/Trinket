import Foundation
import TrinketCore

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
    public static let sanguineCourt = Self("sanguineCourt")
    public static let aureateChoir = Self("aureateChoir")
    public static let rimeVault = Self("rimeVault")
    public static let resonanceHall = Self("resonanceHall")
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
        floorCount: Int = 20,
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
        enemyID: String,
    ) {
        self.spireID = spireID
        self.floor = floor
        self.enemyID = enemyID
    }
}
