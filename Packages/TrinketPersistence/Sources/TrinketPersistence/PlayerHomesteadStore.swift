import Foundation
import Observation
import TrinketContent
import TrinketCore

@MainActor
@Observable
public final class PlayerHomesteadStore {
    private let saveStore: PlayerSaveStore

    public var current: PlayerHomesteadState {
        get { saveStore.homestead }
        set { saveStore.homestead = newValue }
    }

    public init(saveStore: PlayerSaveStore) {
        self.saveStore = saveStore
    }

    public func grant(_ rewards: [ResourceAmount]) {
        var updated = current
        updated.grant(rewards)
        current = updated
    }

    public func buildOrUpgrade(_ definition: HomesteadNodeDefinition, roster: PlayerRosterStore) -> Bool {
        var didUpgrade = false
        do {
            try saveStore.performBatchMutation { save in
                var homestead = save.homestead.homestead()
                var rosterState = save.playerRoster(inventoryItemIDs: Set(save.inventory.items.map(\.id)))
                guard homestead.buildOrUpgrade(definition, roster: &rosterState) else { return }
                save.homestead = SavedHomesteadState(homestead)
                save.roster = SavedRosterState(rosterState)
                didUpgrade = true
            }
        } catch {
            return false
        }
        return didUpgrade
    }
}
