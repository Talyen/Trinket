import Foundation
import os

public struct PlayerSaveFileStore {
    public static let fileName = "PlayerSave.json"
    public static let backupFileName = "PlayerSave.json.bak"
    public static let legacyJourneyKey = "PlayerJourneyStore.current"

    private let directoryURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerSave"
    )

    public init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.directoryURL = supportDirectory.appendingPathComponent(
                PlayerSaveDefaults.applicationSupportSubdirectory,
                isDirectory: true
            )
        }
        encoder = PlayerSaveCoding.makeEncoder()
        decoder = PlayerSaveCoding.makeDecoder()
    }

    public var saveFileURL: URL {
        directoryURL.appendingPathComponent(Self.fileName)
    }

    public var backupFileURL: URL {
        directoryURL.appendingPathComponent(Self.backupFileName)
    }

    public func load() -> PlayerSave? {
        ensureDirectoryExists()

        if let save = loadSave(from: saveFileURL) {
            return save
        }

        if let save = loadSave(from: backupFileURL) {
            logger.warning("Recovered player save from backup file.")
            return save
        }

        return migrateLegacyUserDefaultsJourney()
    }

    public func save(_ playerSave: PlayerSave) {
        ensureDirectoryExists()

        if fileManager.fileExists(atPath: saveFileURL.path) {
            try? fileManager.removeItem(at: backupFileURL)
            try? fileManager.copyItem(at: saveFileURL, to: backupFileURL)
        }

        let temporaryURL = directoryURL.appendingPathComponent("PlayerSave.json.tmp")
        do {
            let data = try encoder.encode(playerSave)
            try data.write(to: temporaryURL, options: .atomic)
            if fileManager.fileExists(atPath: saveFileURL.path) {
                try fileManager.removeItem(at: saveFileURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: saveFileURL)
        } catch {
            logger.error("Failed to save player progress: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func deleteSave() {
        try? fileManager.removeItem(at: saveFileURL)
        try? fileManager.removeItem(at: backupFileURL)
        try? fileManager.removeItem(at: directoryURL.appendingPathComponent("PlayerSave.json.tmp"))
    }

    private func loadSave(from url: URL) -> PlayerSave? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let save = try decoder.decode(PlayerSave.self, from: data)
            return migrated(save)
        } catch {
            logger.error("Failed to load player save: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func migrated(_ save: PlayerSave) -> PlayerSave {
        PlayerSaveSanitizer.sanitize(PlayerSaveMigration.migrate(save))
    }

    private func migrateLegacyUserDefaultsJourney() -> PlayerSave? {
        guard let data = UserDefaults.standard.data(forKey: Self.legacyJourneyKey),
              let journey = try? decoder.decode(JourneyProgressState.self, from: data)
        else {
            return nil
        }

        var playerSave = PlayerSave.fresh
        playerSave.journey = journey
        save(playerSave)
        UserDefaults.standard.removeObject(forKey: Self.legacyJourneyKey)
        logger.info("Migrated legacy journey progress into PlayerSave.")
        return playerSave
    }

    private func ensureDirectoryExists() {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
}
