import SwiftUI

@MainActor
@Observable
final class PlayerJourneyStore {
    private let saveStore: PlayerSaveStore

    var current: JourneyProgressState {
        get { saveStore.journey }
        set { saveStore.journey = newValue }
    }

    init(saveStore: PlayerSaveStore) {
        self.saveStore = saveStore
    }

    func complete(_ stage: Stage, in chapters: [Chapter]) {
        var updated = current
        updated.complete(stage, in: chapters)
        current = updated
    }

    func markRewardsClaimed(for stage: Stage) {
        var updated = current
        updated.markRewardsClaimed(for: stage)
        current = updated
    }

    var mapScrollRequest: MapScrollRequest?

    func requestMapScroll(to targetID: String) {
        mapScrollRequest = MapScrollRequest(targetID: targetID)
    }

    func clearMapScrollRequest(_ request: MapScrollRequest) {
        if mapScrollRequest?.id == request.id {
            mapScrollRequest = nil
        }
    }
}
