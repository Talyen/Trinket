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
        url = Self.url(for: storeURL, kind: .pending)
        hasPendingSave = FileManager.default.fileExists(atPath: url.path)
    }

    isolated deinit {
        retryTask?.cancel()
    }

    enum SidecarKind {
        case pending
        case previous
    }

    nonisolated static func url(for storeURL: URL, kind: SidecarKind = .pending) -> URL {
        let pending = storeURL.appendingPathExtension("pending-save.json")
        switch kind {
        case .pending:
            return pending
        case .previous:
            return pending.deletingPathExtension().appendingPathExtension("previous.json")
        }
    }

    /// Back-compat alias used by store configuration cleanup.
    nonisolated static func previousURL(for storeURL: URL) -> URL {
        url(for: storeURL, kind: .previous)
    }

    var previousFileURL: URL {
        url.deletingPathExtension().appendingPathExtension("previous.json")
    }

    /// Versioned corrupt-sample URL so a second corrupt launch archives
    /// beside the first instead of destroying forensics.
    var nextCorruptFileURL: URL {
        let base = url.appendingPathExtension("unreadable")
        let manager = FileManager.default
        guard manager.fileExists(atPath: base.path) else { return base }
        var index = 2
        while manager.fileExists(atPath: base.appendingPathExtension("\(index)").path) {
            index += 1
        }
        return base.appendingPathExtension("\(index)")
    }

    /// Atomic sidecar write shared by pending/previous/restore paths.
    /// Pure file helper (nonisolated) so future callers can move sidecar I/O
    /// off the store's actor without restructuring call sites.
    nonisolated static func writeDataAtomically(_ data: Data, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func writeDataAtomically(_ data: Data, to destination: URL) throws {
        try Self.writeDataAtomically(data, to: destination)
    }

    /// Record encode/decode without actor state, for the same future use.
    nonisolated static func encodedRecord(save: PlayerSave, cloudState: Data?) throws -> Data {
        try JSONEncoder().encode(Record(save: save, cloudState: cloudState))
    }

    nonisolated static func decodedRecord(from data: Data) throws -> Record {
        try JSONDecoder().decode(Record.self, from: data)
    }

    /// True when the error means "device locked before first unlock" rather
    /// than broken storage. Callers keep the degraded flag truthful (writes
    /// genuinely cannot complete) but log the transient cause and rely on the
    /// existing retry/backoff to land the write after unlock.
    nonisolated static func isFileProtectionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSCocoaErrorDomain else { return false }
        return nsError.code == CocoaError.fileReadNoPermission.rawValue
            || nsError.code == CocoaError.fileWriteNoPermission.rawValue
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
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: url, to: nextCorruptFileURL)
        hasPendingSave = false
    }

    func read() throws -> Record? {
        guard hasPendingSave else { return nil }
        do {
            return try Self.decodedRecord(from: Data(contentsOf: url))
        } catch {
            if Self.isFileProtectionError(error) {
                throw PlayerSavePersistenceError.storeUnavailable("Device locked; retry after first unlock.")
            }
            throw error
        }
    }

    func restore(into root: PlayerSaveRoot, context: ModelContext, preservesPrevious: Bool) throws {
        guard let record = try read() else { return }
        let recovered = try record.restoredSave()
        if preservesPrevious, root.toPlayerSave().hasDomainDifference(from: recovered) {
            try preservePrevious(save: root.toPlayerSave(), cloudState: root.cloudStatePayload)
        }
        root.apply(recovered, slices: .all, context: context)
        root.cloudStatePayload = record.cloudState
    }

    /// Result of a recovery-file write attempt: whether the primary write
    /// still needs a background retry. Memory-fallback writes stay pending by
    /// design (no durable primary exists) but report no retry — retries run
    /// only while the app runs and cannot outlive the fallback session.
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
        do {
            try writeDataAtomically(Self.encodedRecord(save: save, cloudState: cloudState), to: url)
        } catch {
            if Self.isFileProtectionError(error) {
                throw PlayerSavePersistenceError.storeUnavailable("Device locked; retry after first unlock.")
            }
            throw error
        }
        hasPendingSave = true
    }

    func preservePrevious(save: PlayerSave, cloudState: Data?) throws {
        let data = try Self.encodedRecord(save: save, cloudState: cloudState)
        try writeDataAtomically(data, to: previousFileURL)
    }

    /// Clears only the pending record. Forensics (`previous.json`,
    /// versioned `.unreadable` samples) survive a successful persist by
    /// design; explicit resets wipe them via `clearForensics` /
    /// `PlayerSaveStoreConfiguration.cleanStoreFiles`.
    func clear() throws {
        guard hasPendingSave else { return }
        try FileManager.default.removeItem(at: url)
        hasPendingSave = false
    }

    func clearForensics() throws {
        try clear()
        if FileManager.default.fileExists(atPath: previousFileURL.path) {
            try FileManager.default.removeItem(at: previousFileURL)
        }
    }

    /// Schedules a bounded-backoff retry of a durable write while the app
    /// runs. Misnamed historically — the work stays on the store's actor;
    /// "background" means outside the triggering call, not off-thread.
    func scheduleRetry(_ attempt: @escaping @MainActor () -> Bool) {
        retryInBackground(attempt)
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
