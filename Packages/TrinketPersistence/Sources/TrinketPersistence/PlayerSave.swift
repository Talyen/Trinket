import Foundation

public struct PlayerSave: Equatable, Sendable {
    public static let currentSchemaVersion = 6

    public var schemaVersion: Int
    public var modifiedAt: Date
    public var sessionGeneration: UInt64
    public var journey: JourneyProgressState
    public var roster: PlayerRosterState
    public var inventory: PlayerInventoryState
    public var homestead: PlayerHomesteadState

    public static var fresh: PlayerSave {
        PlayerSave(
            schemaVersion: currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            journey: .initial,
            roster: .freshStart,
            inventory: .freshStart,
            homestead: .freshStart
        )
    }

    public static var testSeed: PlayerSave {
        PlayerSave(
            schemaVersion: currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            journey: .initial,
            roster: .testSeed,
            inventory: .testSeed,
            homestead: .testSeed
        )
    }

    public init(
        schemaVersion: Int,
        modifiedAt: Date,
        sessionGeneration: UInt64 = 0,
        journey: JourneyProgressState,
        roster: PlayerRosterState,
        inventory: PlayerInventoryState,
        homestead: PlayerHomesteadState = .freshStart
    ) {
        self.schemaVersion = schemaVersion
        self.modifiedAt = modifiedAt
        self.sessionGeneration = sessionGeneration
        self.journey = journey
        self.roster = roster
        self.inventory = inventory
        self.homestead = homestead
    }



    public func markedLocalMutation(at date: Date = Date()) -> PlayerSave {
        var updated = self
        updated.modifiedAt = date
        updated.schemaVersion = Self.currentSchemaVersion
        return updated
    }
}

extension PlayerSave: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case modifiedAt
        case sessionGeneration
        case journey
        case roster
        case inventory
        case homestead
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
        sessionGeneration = try container.decodeIfPresent(UInt64.self, forKey: .sessionGeneration) ?? 0
        journey = try container.decode(JourneyProgressState.self, forKey: .journey)
        let wireInventory = try container.decode(WireInventoryState.self, forKey: .inventory)
        inventory = wireInventory.inventory()
        let wireRoster = try container.decode(WireRosterState.self, forKey: .roster)
        roster = wireRoster.roster(inventory: inventory)
        homestead = try container.decodeIfPresent(WireHomesteadState.self, forKey: .homestead)?
            .homestead() ?? .freshStart
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(sessionGeneration, forKey: .sessionGeneration)
        try container.encode(journey, forKey: .journey)
        try container.encode(WireRosterState(roster), forKey: .roster)
        try container.encode(WireInventoryState(inventory), forKey: .inventory)
        try container.encode(WireHomesteadState(homestead), forKey: .homestead)
    }
}
