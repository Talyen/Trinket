import Foundation
import Observation
import TrinketContent
import TrinketCore

@MainActor
@Observable
public final class PlayerInventoryStore {
    private let saveStore: PlayerSaveStore

    public var current: PlayerInventoryState {
        get { saveStore.inventory }
        set { saveStore.inventory = newValue }
    }

    public init(saveStore: PlayerSaveStore) {
        self.saveStore = saveStore
    }

    public func addRewardItem(from template: InventoryItem, for stage: Stage) {
        var updated = current
        updated.addRewardItem(from: template, for: stage)
        current = updated
    }
}
