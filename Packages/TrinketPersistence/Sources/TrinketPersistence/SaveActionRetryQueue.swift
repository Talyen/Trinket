import Foundation
import Observation

/// Owns each keyed intent from submission through retry completion. A newer
/// submission supersedes the old callback before either can schedule more work.
@MainActor
@Observable
final class SaveActionRetryQueue {
    private struct Entry {
        let id: UUID
        var task: Task<Void, Never>?
    }

    @ObservationIgnored private var entries: [String: Entry] = [:]
    private(set) var isRetrying = false

    /// Reserve ownership before running the synchronous action: it can submit
    /// another action with the same key, or invalidate the save generation.
    func begin(key: String) -> UUID {
        entries[key]?.task?.cancel()
        let id = UUID()
        entries[key] = Entry(id: id, task: nil)
        updateRetrying()
        return id
    }

    func schedule(key: String, id: UUID, attempt: @escaping @MainActor () -> PlayerSavePersistenceError?) {
        guard isCurrent(key: key, id: id) else { return }
        let task = Task { @MainActor [weak self] in
            var delay = SaveRetryPolicy.initialDelay
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(delay)) } catch { break }
                guard self?.isCurrent(key: key, id: id) == true, !Task.isCancelled else { break }
                let failure = attempt()
                // The callback may synchronously replace itself or reset the save.
                guard self?.isCurrent(key: key, id: id) == true, !Task.isCancelled,
                      failure?.isRetryable == true else { break }
                delay = SaveRetryPolicy.nextDelay(after: delay)
            }
            self?.finish(key: key, id: id)
        }
        entries[key]?.task = task
        updateRetrying()
    }

    func cancelAll() {
        for entry in entries.values {
            entry.task?.cancel()
        }
        entries.removeAll()
        isRetrying = false
    }

    func finish(key: String, id: UUID) {
        // A cancelled task may finish after a replacement with the same key.
        guard isCurrent(key: key, id: id) else { return }
        entries[key] = nil
        updateRetrying()
    }

    private func isCurrent(key: String, id: UUID) -> Bool {
        entries[key]?.id == id
    }

    private func updateRetrying() {
        isRetrying = entries.values.contains { $0.task != nil }
    }
}

/// Commit failures belong to the synchronous action that performed them.
@MainActor
final class SaveActionAttempt {
    private(set) var failure: PlayerSavePersistenceError?

    func record(_ error: PlayerSavePersistenceError) {
        // A later transient failure cannot make a rejected action retryable.
        guard failure?.isRetryable != false else { return }
        failure = error
    }
}
