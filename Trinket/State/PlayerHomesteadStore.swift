import Foundation
import Observation
import TrinketCore

@MainActor
@Observable
final class PlayerHomesteadStore {
    private let saveStore: PlayerSaveStore

    var current: PlayerHomesteadState {
        get { saveStore.homestead }
        set { saveStore.homestead = newValue }
    }

    init(saveStore: PlayerSaveStore) {
        self.saveStore = saveStore
    }

    func grant(_ rewards: [ResourceAmount]) {
        var updated = current
        updated.grant(rewards)
        current = updated
    }

    func buildOrUpgrade(_ definition: HomesteadNodeDefinition, roster: PlayerRosterStore) -> Bool {
        var homestead = current
        var rosterState = roster.current
        guard homestead.buildOrUpgrade(definition, roster: &rosterState) else { return false }
        roster.current = rosterState
        current = homestead
        return true
    }
}
