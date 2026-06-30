import Foundation
import SwiftUI

@MainActor
@Observable
final class PlayerSaveStore {
    private let fileStore: PlayerSaveFileStore
    private var save: PlayerSave

    var journey: JourneyProgressState {
        get { save.journey }
        set {
            save.journey = newValue
            persist()
        }
    }

    var roster: PlayerRosterState {
        get { resolvedRoster() }
        set {
            save.roster = SavedRosterState(newValue)
            save.roster = Self.sanitizeRoster(save.roster, inventoryItemIDs: Self.inventoryItemIDs(from: save.inventory))
            persist()
        }
    }

    var inventory: PlayerInventoryState {
        get { save.inventory.inventory() }
        set {
            save.inventory = SavedInventoryState(newValue)
            save.roster = Self.sanitizeRoster(save.roster, inventoryItemIDs: Self.inventoryItemIDs(from: save.inventory))
            persist()
        }
    }

    init(fileStore: PlayerSaveFileStore = PlayerSaveFileStore()) {
        self.fileStore = fileStore
        save = fileStore.load() ?? .fresh
        save = Self.sanitize(save)
    }

    func resetGameplayProgress() {
        save = .fresh
        persist()
    }

    func applyTestSeed() {
        save = .testSeed
        persist()
    }

    private func persist() {
        fileStore.save(save)
    }

    private func resolvedRoster() -> PlayerRosterState {
        save.playerRoster(inventoryItemIDs: Self.inventoryItemIDs(from: save.inventory))
    }

    private static func sanitize(_ save: PlayerSave) -> PlayerSave {
        var sanitized = save
        sanitized.inventory = SavedInventoryState(Self.sanitizeInventory(save.inventory.inventory()))
        sanitized.roster = Self.sanitizeRoster(
            sanitized.roster,
            inventoryItemIDs: Self.inventoryItemIDs(from: sanitized.inventory)
        )
        return sanitized
    }

    private static func sanitizeInventory(_ inventory: PlayerInventoryState) -> PlayerInventoryState {
        var seenIDs = Set<String>()
        let uniqueItems = inventory.items.filter { item in
            guard !seenIDs.contains(item.id) else { return false }
            seenIDs.insert(item.id)
            return true
        }
        return PlayerInventoryState(items: uniqueItems)
    }

    private static func sanitizeRoster(
        _ roster: SavedRosterState,
        inventoryItemIDs: Set<String>
    ) -> SavedRosterState {
        var sanitized = roster
        sanitized.equipmentLoadouts = roster.equipmentLoadouts.mapValues { savedLoadout in
            SavedEquipmentLoadout(savedLoadout.loadout(inventoryItemIDs: inventoryItemIDs))
        }
        return sanitized
    }

    private static func inventoryItemIDs(from inventory: SavedInventoryState) -> Set<String> {
        Set(inventory.items.map(\.id))
    }
}
