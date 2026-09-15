import Foundation
import SwiftData

@MainActor
final class PendingSaveRecovery {
    struct Record: Codable {
        let version: Int
        let snapshot: CloudSaveSnapshot
        let sessionGeneration: UInt64
        let cloudState: Data?

        init(save: PlayerSave, cloudState: Data?) {
            version = 1
            snapshot = CloudSaveSnapshot(save)
            sessionGeneration = save.sessionGeneration
            self.cloudState = cloudState
        }

        func restoredSave() throws -> PlayerSave {
            guard version == 1 else { throw PlayerSavePersistenceError.invalidSave("Unsupported recovery record.") }
            var save = try snapshot.restored()
            save.sessionGeneration = sessionGeneration
            return save
        }
    }

    let url: URL
    private(set) var hasPendingSave: Bool
    private var retryTask: Task<Void, Never>?

    init(storeURL: URL) {
        url = Self.url(for: storeURL)
        hasPendingSave = FileManager.default.fileExists(atPath: url.path)
    }

    isolated deinit {
        retryTask?.cancel()
    }

    nonisolated static func url(for storeURL: URL) -> URL {
        storeURL.appendingPathExtension("pending-save.json")
    }

    nonisolated static func previousURL(for storeURL: URL) -> URL {
        url(for: storeURL).deletingPathExtension().appendingPathExtension("previous.json")
    }

    var previousFileURL: URL {
        url.deletingPathExtension().appendingPathExtension("previous.json")
    }

    /// Atomic sidecar write shared by pending/previous/restore paths.
    private func writeDataAtomically(_ data: Data, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func pendingData() throws -> Data? {
        guard hasPendingSave else { return nil }
        return try Data(contentsOf: url)
    }

    func restorePendingData(_ data: Data?) throws {
        if let data {
            try writeDataAtomically(data, to: url)
            hasPendingSave = true
        } else {
            try clear()
        }
    }

    func moveCorruptAside() throws {
        guard hasPendingSave else { return }
        let corruptURL = url.appendingPathExtension("unreadable")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: corruptURL.path) {
            try FileManager.default.removeItem(at: corruptURL)
        }
        try FileManager.default.moveItem(at: url, to: corruptURL)
        hasPendingSave = false
    }

    func read() throws -> Record? {
        guard hasPendingSave else { return nil }
        return try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
    }

    func restore(into root: PlayerSaveRoot, context: ModelContext, preservesPrevious: Bool) throws {
        guard let record = try read() else { return }
        let recovered = try record.restoredSave()
        if preservesPrevious, root.toPlayerSave() != recovered {
            try preservePrevious(save: root.toPlayerSave(), cloudState: root.cloudStatePayload)
        }
        root.apply(recovered, slices: .all, context: context)
        root.cloudStatePayload = record.cloudState
    }

    func persist(
        save: PlayerSave, cloudState: Data?, memoryFallback: Bool,
        primaryWrite: () throws -> Void,
    ) throws -> Bool {
        if memoryFallback || hasPendingSave {
            try write(save: save, cloudState: cloudState)
        }
        do {
            try primaryWrite()
        } catch {
            try write(save: save, cloudState: cloudState)
            return true
        }
        if !memoryFallback {
            do { try clear() } catch { return true }
        }
        return false
    }

    func write(save: PlayerSave, cloudState: Data?) throws {
        let data = try JSONEncoder().encode(Record(save: save, cloudState: cloudState))
        try writeDataAtomically(data, to: url)
        hasPendingSave = true
    }

    func preservePrevious(save: PlayerSave, cloudState: Data?) throws {
        let data = try JSONEncoder().encode(Record(save: save, cloudState: cloudState))
        try writeDataAtomically(data, to: previousFileURL)
    }

    func clear() throws {
        guard hasPendingSave else { return }
        try FileManager.default.removeItem(at: url)
        hasPendingSave = false
        if FileManager.default.fileExists(atPath: previousFileURL.path) {
            try FileManager.default.removeItem(at: previousFileURL)
        }
    }

    func retryInBackground(_ attempt: @escaping @MainActor () -> Bool) {
        guard retryTask == nil else { return }
        retryTask = Task { @MainActor [weak self] in
            var delay = SaveRetryPolicy.initialDelay
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(delay)) } catch { break }
                guard self != nil else { return }
                if attempt() {
                    break
                }
                delay = SaveRetryPolicy.nextDelay(after: delay)
            }
            self?.retryTask = nil
        }
    }
}
