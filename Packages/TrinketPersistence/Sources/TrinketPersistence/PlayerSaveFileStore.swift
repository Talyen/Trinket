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
        switch loadOutcome() {
        case let .loaded(save):
            save
        case .missing, .corrupt:
            nil
        }
    }

    func loadOutcome() -> PlayerSaveLoadOutcome {
        ensureDirectoryExists()

        let primaryExists = fileManager.fileExists(atPath: saveFileURL.path)
        let backupExists = fileManager.fileExists(atPath: backupFileURL.path)

        if let save = loadSave(from: saveFileURL) {
            return .loaded(save)
        }

        if let save = loadSave(from: backupFileURL) {
            logger.warning("Recovered player save from backup file.")
            return .loaded(save)
        }

        if let save = migrateLegacyUserDefaultsJourney() {
            return .loaded(save)
        }

        if primaryExists || backupExists {
            logger.error("Player save files exist but could not be decoded.")
            return .corrupt
        }

        return .missing
    }

    public func quarantineCorruptSaves() {
        for url in [saveFileURL, backupFileURL] where fileManager.fileExists(atPath: url.path) {
            let quarantineURL = url.appendingPathExtension("corrupt")
            try? fileManager.removeItem(at: quarantineURL)
            try? fileManager.moveItem(at: url, to: quarantineURL)
        }
    }

    public func save(_ playerSave: PlayerSave) throws {
        ensureDirectoryExists()

        if fileManager.fileExists(atPath: saveFileURL.path) {
            if fileManager.fileExists(atPath: backupFileURL.path) {
                try fileManager.removeItem(at: backupFileURL)
            }
            try fileManager.copyItem(at: saveFileURL, to: backupFileURL)
        }

        let temporaryURL = directoryURL.appendingPathComponent("PlayerSave.json.tmp")
        do {
            let data = try encoder.encode(playerSave)
            try data.write(to: temporaryURL, options: .atomic)
            if fileManager.fileExists(atPath: saveFileURL.path) {
                _ = try fileManager.replaceItemAt(saveFileURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: saveFileURL)
            }
        } catch {
            logger.error("Failed to save player progress: \(error.localizedDescription, privacy: .public)")
            throw PlayerSavePersistenceError.writeFailed
        }
    }

    public func deleteSave() {
        for url in [saveFileURL, backupFileURL, directoryURL.appendingPathComponent("PlayerSave.json.tmp")] {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            do {
                try fileManager.removeItem(at: url)
            } catch {
                logger.error("Failed to delete save file at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
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
        guard let data = UserDefaults.standard.data(forKey: Self.legacyJourneyKey) else {
            return nil
        }

        let journey: JourneyProgressState
        do {
            journey = try decoder.decode(JourneyProgressState.self, from: data)
        } catch {
            logger.error(
                "Failed to decode legacy journey progress: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }

        var playerSave = PlayerSave.fresh
        playerSave.journey = journey
        do {
            try save(playerSave)
        } catch {
            logger.error(
                "Failed to persist migrated legacy journey progress: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
        UserDefaults.standard.removeObject(forKey: Self.legacyJourneyKey)
        logger.info("Migrated legacy journey progress into PlayerSave.")
        return playerSave
    }

    private func ensureDirectoryExists() {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            logger.error(
                "Failed to create save directory: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
