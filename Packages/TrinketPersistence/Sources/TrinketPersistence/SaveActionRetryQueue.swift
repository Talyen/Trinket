import Foundation
import Observation

/// Owns queued actions and their lifetime; diagnostics are not retry outcomes.
@MainActor
@Observable
final class SaveActionRetryQueue {
    private struct Entry {
        let id: UUID
        let task: Task<Void, Never>
    }

    @ObservationIgnored private var entries: [String: Entry] = [:]
    private(set) var isRetrying = false

    func schedule(key: String, attempt: @escaping @MainActor () -> PlayerSavePersistenceError?) {
        guard entries[key] == nil else { return }
        let id = UUID()
        let task = Task { @MainActor [weak self] in
            var delay = SaveRetryPolicy.initialDelay
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(delay)) } catch { break }
                guard self != nil, !Task.isCancelled else { break }
                guard attempt()?.isRetryable == true else { break }
                delay = SaveRetryPolicy.nextDelay(after: delay)
            }
            self?.finish(key: key, id: id)
        }
        entries[key] = Entry(id: id, task: task)
        isRetrying = true
    }

    func cancelAll() {
        for entry in entries.values {
            entry.task.cancel()
        }
        entries.removeAll()
        isRetrying = false
    }

    private func finish(key: String, id: UUID) {
        // A cancelled task may finish after a replacement with the same key.
        guard entries[key]?.id == id else { return }
        entries[key] = nil
        isRetrying = !entries.isEmpty
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
