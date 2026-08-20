import Foundation
import TrinketContent
import TrinketCore

@MainActor
public extension PlayerSaveStore {
    @discardableResult
    func mutateRoster(
        logging message: String = "Failed to persist roster edits",
        _ update: (inout PlayerRosterState) -> Void
    ) -> Bool {
        persistBatch(logging: message) { save in
            var roster = save.roster
            update(&roster)
            save.roster = roster
        }
    }

    @discardableResult
    func setInventoryItems(_ items: [InventoryItem]) -> Bool {
        persistBatch(logging: "Failed to persist inventory edits") { save in
            var inventory = save.inventory
            inventory.items = items
            save.inventory = inventory
        }
    }
}
