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
            save = PlayerSaveSanitizer.sanitize(save)
            persist()
        }
    }

    var inventory: PlayerInventoryState {
        get { save.inventory.inventory() }
        set {
            save.inventory = SavedInventoryState(newValue)
            save = PlayerSaveSanitizer.sanitize(save)
            persist()
        }
    }

    init(fileStore: PlayerSaveFileStore = PlayerSaveFileStore()) {
        self.fileStore = fileStore
        let loaded = fileStore.load() ?? .fresh
        save = PlayerSaveSanitizer.sanitize(PlayerSaveMigration.migrate(loaded))
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
        save.playerRoster(inventoryItemIDs: Set(save.inventory.items.map(\.id)))
    }
}
