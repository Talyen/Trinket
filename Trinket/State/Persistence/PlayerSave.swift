import Foundation

struct PlayerSave: Codable, Equatable {
    static let currentSchemaVersion = 4

    var schemaVersion: Int
    var modifiedAt: Date
    var journey: JourneyProgressState
    var roster: SavedRosterState
    var inventory: SavedInventoryState

    static var fresh: PlayerSave {
        PlayerSave(
            schemaVersion: currentSchemaVersion,
            modifiedAt: Date(),
            journey: .initial,
            roster: SavedRosterState(.freshStart),
            inventory: SavedInventoryState(.freshStart)
        )
    }

    static var testSeed: PlayerSave {
        PlayerSave(
            schemaVersion: currentSchemaVersion,
            modifiedAt: Date(),
            journey: .initial,
            roster: SavedRosterState(.testSeed),
            inventory: SavedInventoryState(.testSeed)
        )
    }

    init(
        schemaVersion: Int,
        modifiedAt: Date,
        journey: JourneyProgressState,
        roster: SavedRosterState,
        inventory: SavedInventoryState
    ) {
        self.schemaVersion = schemaVersion
        self.modifiedAt = modifiedAt
        self.journey = journey
        self.roster = roster
        self.inventory = inventory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
        journey = try container.decode(JourneyProgressState.self, forKey: .journey)
        roster = try container.decode(SavedRosterState.self, forKey: .roster)
        inventory = try container.decode(SavedInventoryState.self, forKey: .inventory)
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
