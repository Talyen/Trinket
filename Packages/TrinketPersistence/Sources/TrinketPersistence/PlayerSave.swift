import Foundation

public struct PlayerSave: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 6

    public var schemaVersion: Int
    public var modifiedAt: Date
    public var sessionGeneration: UInt64
    public var journey: JourneyProgressState
    public var roster: SavedRosterState
    public var inventory: SavedInventoryState
    public var homestead: SavedHomesteadState

    public static var fresh: PlayerSave {
        PlayerSave(
            schemaVersion: currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            journey: .initial,
            roster: SavedRosterState(.freshStart),
            inventory: SavedInventoryState(.freshStart),
            homestead: SavedHomesteadState(.freshStart)
        )
    }

    public static var testSeed: PlayerSave {
        PlayerSave(
            schemaVersion: currentSchemaVersion,
            modifiedAt: Date(),
            sessionGeneration: 0,
            journey: .initial,
            roster: SavedRosterState(.testSeed),
            inventory: SavedInventoryState(.testSeed),
            homestead: SavedHomesteadState(.testSeed)
        )
    }

    public init(
        schemaVersion: Int,
        modifiedAt: Date,
        sessionGeneration: UInt64 = 0,
        journey: JourneyProgressState,
        roster: SavedRosterState,
        inventory: SavedInventoryState,
        homestead: SavedHomesteadState = SavedHomesteadState(.freshStart)
    ) {
        self.schemaVersion = schemaVersion
        self.modifiedAt = modifiedAt
        self.sessionGeneration = sessionGeneration
        self.journey = journey
        self.roster = roster
        self.inventory = inventory
        self.homestead = homestead
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
        sessionGeneration = try container.decodeIfPresent(UInt64.self, forKey: .sessionGeneration) ?? 0
        journey = try container.decode(JourneyProgressState.self, forKey: .journey)
        roster = try container.decode(SavedRosterState.self, forKey: .roster)
        inventory = try container.decode(SavedInventoryState.self, forKey: .inventory)
        homestead = try container.decodeIfPresent(SavedHomesteadState.self, forKey: .homestead)
            ?? SavedHomesteadState(.freshStart)
    }

    public func playerRoster(inventoryItemIDs: Set<String>) -> PlayerRosterState {
        roster.roster(inventoryItemIDs: inventoryItemIDs)
    }

    public func markedLocalMutation(at date: Date = Date()) -> PlayerSave {
        var updated = self
        updated.modifiedAt = date
        updated.schemaVersion = Self.currentSchemaVersion
        return updated
    }
}
