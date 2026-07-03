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
        var homestead = current
        var rosterState = roster.current
        guard homestead.buildOrUpgrade(definition, roster: &rosterState) else { return false }
        roster.current = rosterState
        current = homestead
        return true
    }
}
