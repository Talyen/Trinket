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

    public func buildOrUpgrade(_ definition: HomesteadNodeDefinition, roster: PlayerRosterStore) -> HomesteadBuildResult {
        var didUpgrade = false
        do {
            try saveStore.performBatchMutation { save in
                var homestead = save.homestead
                var rosterState = save.roster
                guard homestead.buildOrUpgrade(definition, roster: &rosterState) else { return }
                save.homestead = homestead
                save.roster = rosterState
                didUpgrade = true
            }
        } catch {
            return .persistFailed
        }
        return didUpgrade ? .success : .insufficientResources
    }
}
