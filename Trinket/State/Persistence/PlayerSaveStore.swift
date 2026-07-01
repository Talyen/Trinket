import Foundation
import SwiftUI

@MainActor
@Observable
final class PlayerSaveStore {
    private let fileStore: PlayerSaveFileStore
    private var save: PlayerSave
    var onLocalSave: ((PlayerSave) -> Void)?

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

    var homestead: PlayerHomesteadState {
        get { save.homestead.homestead() }
        set {
            save.homestead = SavedHomesteadState(newValue)
            save = PlayerSaveSanitizer.sanitize(save)
            persist()
        }
    }

    var currentSave: PlayerSave {
        save
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

    func applyRemoteSave(_ remoteSave: PlayerSave) {
        save = PlayerSaveSanitizer.sanitize(PlayerSaveMigration.migrate(remoteSave))
        fileStore.save(save)
    }

    private func persist() {
        save = save.markedLocalMutation()
        fileStore.save(save)
        onLocalSave?(save)
    }

    private func resolvedRoster() -> PlayerRosterState {
        save.playerRoster(inventoryItemIDs: Set(save.inventory.items.map(\.id)))
    }
}
