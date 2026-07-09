import Foundation
import TrinketContent
import TrinketCore

/// Collection discovery acknowledgment — which unlocked combatants and owned items
/// the player has already opened in a Collection-context detail sheet.
///
/// Homestead tab badges are a separate ephemeral affordance indicator (see
/// `PlayerShellSessionStore.acknowledgedHomesteadActionableFingerprint`), not part of this state.
public struct PlayerCollectionAttentionState: Equatable, Sendable {
    public var viewedCombatantIDs: Set<String>
    /// Instance-level acknowledgment (Astral / unique loot).
    public var viewedItemIDs: Set<String>
    /// Template-level acknowledgment for common (Basic) gear — viewing one copy
    /// suppresses NEW for later copies of the same template.
    public var viewedItemTemplateIDs: Set<String>

    public init(
        viewedCombatantIDs: Set<String> = [],
        viewedItemIDs: Set<String> = [],
        viewedItemTemplateIDs: Set<String> = []
    ) {
        self.viewedCombatantIDs = viewedCombatantIDs
        self.viewedItemIDs = viewedItemIDs
        self.viewedItemTemplateIDs = viewedItemTemplateIDs
    }

    /// Starters are granted at install — they are not discovery signals.
    public static var freshStart: PlayerCollectionAttentionState {
        PlayerCollectionAttentionState(
            viewedCombatantIDs: [
                PlayerRosterState.starterHeroID,
                PlayerRosterState.starterPetID
            ],
            viewedItemIDs: [],
            viewedItemTemplateIDs: []
        )
    }

    /// Seeded inventory and starters are fixture content, not a discovery inbox for UI tests.
    /// Non-starter unlocks remain unviewed so unlock/NEW flows can still be exercised under seed.
    public static var testSeed: PlayerCollectionAttentionState {
        let seededItems = PlayerInventoryState.testSeed.items
        return PlayerCollectionAttentionState(
            viewedCombatantIDs: [
                PlayerRosterState.starterHeroID,
                PlayerRosterState.starterPetID
            ],
            viewedItemIDs: Set(seededItems.map(\.id)),
            viewedItemTemplateIDs: Set(
                seededItems.filter { $0.rarity == .basic }.map(\.templateID)
            )
        )
    }

    public mutating func markCombatantAsViewed(id: String) {
        viewedCombatantIDs.insert(id)
    }

    public mutating func markCombatantsAsViewed(ids: some Sequence<String>) {
        viewedCombatantIDs.formUnion(ids)
    }

    public mutating func markItemAsViewed(_ item: InventoryItem) {
        viewedItemIDs.insert(item.id)
        if item.rarity == .basic {
            viewedItemTemplateIDs.insert(item.templateID)
        }
    }

    public mutating func markItemsAsViewed(_ items: some Sequence<InventoryItem>) {
        for item in items {
            markItemAsViewed(item)
        }
    }

    /// Whether an owned item should show a Collection NEW marker.
    public func showsNewMarker(for item: InventoryItem) -> Bool {
        switch item.rarity {
        case .basic:
            return !viewedItemTemplateIDs.contains(item.templateID)
        case .astral:
            return !viewedItemIDs.contains(item.id)
        }
    }
}

public extension PlayerCollectionAttentionState {
    var current: PlayerCollectionAttentionState {
        get { self }
        set { self = newValue }
    }
}
