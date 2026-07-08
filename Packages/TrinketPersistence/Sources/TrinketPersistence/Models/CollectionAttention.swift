import Foundation

/// Collection discovery acknowledgment — which unlocked combatants and owned items
/// the player has already opened in a Collection-context detail sheet.
public struct PlayerCollectionAttentionState: Equatable, Sendable {
    public var viewedCombatantIDs: Set<String>
    public var viewedItemIDs: Set<String>

    public init(
        viewedCombatantIDs: Set<String> = [],
        viewedItemIDs: Set<String> = []
    ) {
        self.viewedCombatantIDs = viewedCombatantIDs
        self.viewedItemIDs = viewedItemIDs
    }

    /// Starters are granted at install — they are not discovery signals.
    public static var freshStart: PlayerCollectionAttentionState {
        PlayerCollectionAttentionState(
            viewedCombatantIDs: [
                PlayerRosterState.starterHeroID,
                PlayerRosterState.starterPetID
            ],
            viewedItemIDs: []
        )
    }

    /// Seeded inventory and starters are fixture content, not a discovery inbox for UI tests.
    /// Non-starter unlocks remain unviewed so unlock/NEW flows can still be exercised under seed.
    public static var testSeed: PlayerCollectionAttentionState {
        PlayerCollectionAttentionState(
            viewedCombatantIDs: [
                PlayerRosterState.starterHeroID,
                PlayerRosterState.starterPetID
            ],
            viewedItemIDs: Set(PlayerInventoryState.testSeed.items.map(\.id))
        )
    }

    public mutating func markCombatantAsViewed(id: String) {
        viewedCombatantIDs.insert(id)
    }

    public mutating func markItemAsViewed(id: String) {
        viewedItemIDs.insert(id)
    }
}

public extension PlayerCollectionAttentionState {
    var current: PlayerCollectionAttentionState {
        get { self }
        set { self = newValue }
    }
}
