import Foundation
import TrinketContent
import TrinketCore

/// Thin domain facade over `PlayerSaveStore` for roster and inventory edits.
/// Does not own a container — all writes route through the hub.
@MainActor
public struct PlayerRosterStore {
    private let save: PlayerSaveStore

    public init(save: PlayerSaveStore) {
        self.save = save
    }

    @discardableResult
    public func mutateRoster(
        logging message: String = "Failed to persist roster edits",
        _ update: (inout PlayerRosterState) -> Void
    ) -> Bool {
        save.persistBatch(logging: message) { save in
            var roster = save.roster
            update(&roster)
            save.roster = roster
        }
    }

    @discardableResult
    public func setInventoryItems(_ items: [InventoryItem]) -> Bool {
        save.persistBatch(logging: "Failed to persist inventory edits") { save in
            var inventory = save.inventory
            inventory.items = items
            save.inventory = inventory
        }
    }
}
