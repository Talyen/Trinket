import Foundation

struct PlayerSave: Codable, Equatable {
    static let currentSchemaVersion = 5

    var schemaVersion: Int
    var modifiedAt: Date
    var journey: JourneyProgressState
    var roster: SavedRosterState
    var inventory: SavedInventoryState
    var homestead: SavedHomesteadState

    static var fresh: PlayerSave {
        PlayerSave(
            schemaVersion: currentSchemaVersion,
            modifiedAt: Date(),
            journey: .initial,
            roster: SavedRosterState(.freshStart),
            inventory: SavedInventoryState(.freshStart),
            homestead: SavedHomesteadState(.freshStart)
        )
    }

    static var testSeed: PlayerSave {
        PlayerSave(
            schemaVersion: currentSchemaVersion,
            modifiedAt: Date(),
            journey: .initial,
            roster: SavedRosterState(.testSeed),
            inventory: SavedInventoryState(.testSeed),
            homestead: SavedHomesteadState(.testSeed)
        )
    }

    init(
        schemaVersion: Int,
        modifiedAt: Date,
        journey: JourneyProgressState,
        roster: SavedRosterState,
        inventory: SavedInventoryState,
        homestead: SavedHomesteadState = SavedHomesteadState(.freshStart)
    ) {
        self.schemaVersion = schemaVersion
        self.modifiedAt = modifiedAt
        self.journey = journey
        self.roster = roster
        self.inventory = inventory
        self.homestead = homestead
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
        journey = try container.decode(JourneyProgressState.self, forKey: .journey)
        roster = try container.decode(SavedRosterState.self, forKey: .roster)
        inventory = try container.decode(SavedInventoryState.self, forKey: .inventory)
        homestead = try container.decodeIfPresent(SavedHomesteadState.self, forKey: .homestead)
            ?? SavedHomesteadState(.freshStart)
    }

    func playerRoster(inventoryItemIDs: Set<String>) -> PlayerRosterState {
        roster.roster(inventoryItemIDs: inventoryItemIDs)
    }

    func markedLocalMutation(at date: Date = Date()) -> PlayerSave {
        var updated = self
        updated.modifiedAt = date
        updated.schemaVersion = Self.currentSchemaVersion
        return updated
    }
}
