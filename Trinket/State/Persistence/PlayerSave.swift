import Foundation

struct PlayerSave: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var journey: JourneyProgressState
    var roster: SavedRosterState
    var inventory: SavedInventoryState

    static var fresh: PlayerSave {
        PlayerSave(
            schemaVersion: currentSchemaVersion,
            journey: .initial,
            roster: SavedRosterState(.freshStart),
            inventory: SavedInventoryState(.freshStart)
        )
    }

    static var testSeed: PlayerSave {
        PlayerSave(
            schemaVersion: currentSchemaVersion,
            journey: .initial,
            roster: SavedRosterState(.testSeed),
            inventory: SavedInventoryState(.testSeed)
        )
    }

    init(
        schemaVersion: Int,
        journey: JourneyProgressState,
        roster: SavedRosterState,
        inventory: SavedInventoryState
    ) {
        self.schemaVersion = schemaVersion
        self.journey = journey
        self.roster = roster
        self.inventory = inventory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        journey = try container.decode(JourneyProgressState.self, forKey: .journey)
        roster = try container.decode(SavedRosterState.self, forKey: .roster)
        inventory = try container.decode(SavedInventoryState.self, forKey: .inventory)
    }

    func playerRoster(inventoryItemIDs: Set<String>) -> PlayerRosterState {
        roster.roster(inventoryItemIDs: inventoryItemIDs)
    }
}
