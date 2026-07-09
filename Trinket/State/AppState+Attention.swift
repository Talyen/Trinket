import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    func markCombatantAsViewed(id: String) {
        var attention = collectionAttention.current
        attention.markCombatantAsViewed(id: id)
        collectionAttention.current = attention
    }

    func markItemAsViewed(id: String) {
        guard let item = inventory.current.item(matching: id) else { return }
        markItemAsViewed(item)
    }

    func markItemAsViewed(_ item: InventoryItem) {
        guard inventory.current.items.contains(where: { $0.id == item.id }) else { return }
        var attention = collectionAttention.current
        attention.markItemAsViewed(item)
        collectionAttention.current = attention
    }

    func markAllCollectionCombatantsAsViewed(kind: CombatantDetailContext.Kind) {
        let ids: Set<String> = switch kind {
        case .hero: roster.current.unlockedHeroIDs
        case .pet: roster.current.unlockedPetIDs
        }
        var attention = collectionAttention.current
        attention.markCombatantsAsViewed(ids: ids)
        collectionAttention.current = attention
    }

    func markAllCollectionItemsAsViewed() {
        let items = inventory.current.items
        guard !items.isEmpty else { return }
        var attention = collectionAttention.current
        attention.markItemsAsViewed(items)
        collectionAttention.current = attention
    }

    /// Starters are granted at install — they are not "new" discoveries.
    func seedStarterCombatantsAsViewedIfNeeded() {
        markCombatantAsViewed(id: PlayerRosterState.starterHeroID)
        markCombatantAsViewed(id: PlayerRosterState.starterPetID)
    }

    /// One-release import from pre-schema-7 shell session viewed IDs into `PlayerSave`.
    func migrateShellViewedCombatantsToPlayerSaveIfNeeded() {
        let shellViewed = shellSession.viewedCombatantIDs
        guard !shellViewed.isEmpty else { return }
        var attention = collectionAttention.current
        attention.viewedCombatantIDs.formUnion(shellViewed)
        collectionAttention.current = attention
        shellSession.viewedCombatantIDs = []
    }

    func showsCollectionNewMarker(for combatantID: String) -> Bool {
        let rosterState = roster.current
        let isUnlocked = rosterState.unlockedHeroIDs.contains(combatantID)
            || rosterState.unlockedPetIDs.contains(combatantID)
        guard isUnlocked else { return false }
        return !collectionAttention.current.viewedCombatantIDs.contains(combatantID)
    }

    func showsCollectionNewMarker(forItem itemID: String) -> Bool {
        guard let item = inventory.current.item(matching: itemID) else { return false }
        return collectionAttention.current.showsNewMarker(for: item)
    }

    func showsCollectionNewMarker(for item: InventoryItem) -> Bool {
        guard inventory.current.items.contains(where: { $0.id == item.id }) else { return false }
        return collectionAttention.current.showsNewMarker(for: item)
    }

    var unviewedHeroCount: Int {
        let viewed = collectionAttention.current.viewedCombatantIDs
        return roster.current.unlockedHeroIDs.filter { !viewed.contains($0) }.count
    }

    var unviewedPetCount: Int {
        let viewed = collectionAttention.current.viewedCombatantIDs
        return roster.current.unlockedPetIDs.filter { !viewed.contains($0) }.count
    }

    var unviewedItemCount: Int {
        let attention = collectionAttention.current
        return inventory.current.items.filter { attention.showsNewMarker(for: $0) }.count
    }

    /// Inventory shelf preview: unviewed discoveries first, then remaining owned items.
    func collectionInventoryShelfItems(limit: Int = 12) -> [InventoryItem] {
        let attention = collectionAttention.current
        let items = inventory.current.items
        let unviewed = items.filter { attention.showsNewMarker(for: $0) }
        let viewed = items.filter { !attention.showsNewMarker(for: $0) }
        return Array((unviewed + viewed).prefix(limit))
    }

    var collectionActionableCount: Int {
        unviewedHeroCount + unviewedPetCount + unviewedItemCount
    }

    /// Sorted node-id fingerprint of currently affordable Homestead builds/upgrades.
    var homesteadActionableFingerprint: String {
        let homesteadState = homestead.current
        let rosterState = roster.current
        let actionableIDs = GameContent.homesteadNodes.compactMap { definition -> String? in
            let status = HomesteadProjectStatus(
                definition: definition,
                homestead: homesteadState,
                roster: rosterState
            )
            return status.canBuildOrUpgrade ? definition.id.rawValue : nil
        }
        return actionableIDs.sorted().joined(separator: "|")
    }

    var homesteadActionableCount: Int {
        guard !homesteadActionableFingerprint.isEmpty else { return 0 }
        return homesteadActionableFingerprint.split(separator: "|").count
    }

    /// Collection discovery badge — numeric count of unviewed unlocks + inventory.
    var collectionBadge: Int? {
        guard selectedTab != .collection else { return nil }
        let count = collectionActionableCount
        return count > 0 ? count : nil
    }

    /// Homestead affordance badge — numeric count of newly actionable builds since last visit.
    /// Visiting Homestead acknowledges the current fingerprint; the badge returns when the set changes.
    var homesteadBadge: Int? {
        guard selectedTab != .homestead else { return nil }
        let fingerprint = homesteadActionableFingerprint
        guard !fingerprint.isEmpty else { return nil }
        guard fingerprint != shellSession.acknowledgedHomesteadActionableFingerprint else { return nil }
        return homesteadActionableCount
    }

    func acknowledgeHomesteadActionablesIfNeeded() {
        let fingerprint = homesteadActionableFingerprint
        guard fingerprint != shellSession.acknowledgedHomesteadActionableFingerprint else { return }
        shellSession.acknowledgedHomesteadActionableFingerprint = fingerprint
    }
}
