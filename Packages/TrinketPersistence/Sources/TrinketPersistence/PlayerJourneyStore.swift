import Foundation
import Observation
import TrinketContent

@MainActor
@Observable
public final class PlayerJourneyStore {
    private let saveStore: PlayerSaveStore

    public var current: JourneyProgressState {
        get { saveStore.journey }
        set { saveStore.journey = newValue }
    }

    public var mapScrollRequest: MapScrollRequest?

    public init(saveStore: PlayerSaveStore) {
        self.saveStore = saveStore
    }

    public func complete(_ stage: Stage, in chapters: [Chapter]) {
        var updated = current
        updated.complete(stage, in: chapters)
        current = updated
    }

    public func markRewardsClaimed(for stage: Stage) {
        var updated = current
        updated.markRewardsClaimed(for: stage)
        current = updated
    }

    public func requestMapScroll(to targetID: String) {
        mapScrollRequest = MapScrollRequest(targetID: targetID)
    }

    public func clearMapScrollRequest(_ request: MapScrollRequest) {
        if mapScrollRequest?.id == request.id {
            mapScrollRequest = nil
        }
    }
}
