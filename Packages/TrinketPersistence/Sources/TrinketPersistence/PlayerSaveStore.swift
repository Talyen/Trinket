import Foundation
import Observation
import os

@MainActor
@Observable
public final class PlayerSaveStore {
    private let fileStore: PlayerSaveFileStore
    private var save: PlayerSave
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerSave"
    )
    public var onLocalSave: ((PlayerSave) -> Void)?
    public var onRemoteSaveApplied: (() -> Void)?

    public var journey: JourneyProgressState {
        get { save.journey }
        set {
            save.journey = PlayerSaveSanitizer.sanitizeJourney(newValue)
            persist()
        }
    }

    public var roster: PlayerRosterState {
        get { resolvedRoster() }
        set {
            save.roster = SavedRosterState(newValue)
            save = PlayerSaveSanitizer.sanitize(save)
            persist()
        }
    }

    public var inventory: PlayerInventoryState {
        get { save.inventory.inventory() }
        set {
            save.inventory = SavedInventoryState(newValue)
            save = PlayerSaveSanitizer.sanitize(save)
            persist()
        }
    }

    public var homestead: PlayerHomesteadState {
        get { save.homestead.homestead() }
        set {
            save.homestead = SavedHomesteadState(newValue)
            save = PlayerSaveSanitizer.sanitize(save)
            persist()
        }
    }

    public var currentSave: PlayerSave {
        save
    }

    public init(fileStore: PlayerSaveFileStore = PlayerSaveFileStore()) {
        self.fileStore = fileStore
        let loaded = fileStore.load() ?? .fresh
        save = PlayerSaveSanitizer.sanitize(PlayerSaveMigration.migrate(loaded))
    }

    public func performBatchMutation(_ update: (inout PlayerSave) -> Void) {
        update(&save)
        save = PlayerSaveSanitizer.sanitize(save)
        persist()
    }

    public func resetGameplayProgress() {
        save = .fresh
        persist()
    }

    public func applyTestSeed() {
        save = .testSeed
        persist()
    }

    public func applyRemoteSave(_ remoteSave: PlayerSave) {
        save = PlayerSaveSanitizer.sanitize(PlayerSaveMigration.migrate(remoteSave))
        do {
            try fileStore.save(save)
        } catch {
            logger.error("Failed to persist remote save locally: \(error.localizedDescription, privacy: .public)")
        }
        onRemoteSaveApplied?()
    }

    private func persist() {
        save = save.markedLocalMutation()
        do {
            try fileStore.save(save)
            onLocalSave?(save)
        } catch {
            logger.error("Failed to persist local save: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resolvedRoster() -> PlayerRosterState {
        save.playerRoster(inventoryItemIDs: Set(save.inventory.items.map(\.id)))
    }
}
