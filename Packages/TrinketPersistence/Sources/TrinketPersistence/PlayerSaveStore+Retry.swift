import Foundation

/// Single backoff truth for save retries: 0.25s, doubling, capped at 30s.
enum SaveRetryPolicy {
    static let initialDelay = 0.25
    static let maxDelay = 30.0

    static func nextDelay(after current: Double) -> Double {
        min(current * 2, maxDelay)
    }
}

@MainActor
public extension PlayerSaveStore {
    /// Retains a failed action and retries silently with backoff. Keys prevent
    /// duplicate retries; the captured generation prevents late writes across
    /// reset/account boundaries. Each synchronous attempt records its own
    /// persistence failures, without clearing or reading shared diagnostics.
    ///
    /// `action` uses the store's persistence commands. A retryable write failure
    /// schedules another attempt; rejection, success, or an obsolete no-op ends
    /// it. `lastPersistenceError` gates initial scheduling only and remains the
    /// Progress Status diagnostic owned by actual persistence operations.
    func retrySaveAction(key: String, action: @escaping @MainActor () -> Void) {
        let generation = currentSave.sessionGeneration
        let key = "\(generation):\(key)"
        guard let error = lastPersistenceError, error.isRetryable else { return }
        saveActionRetries.schedule(key: key) { [weak self] in
            guard let self, currentSave.sessionGeneration == generation else { return nil }
            return attemptSaveAction(action)
        }
    }

    private func attemptSaveAction(_ action: () -> Void) -> PlayerSavePersistenceError? {
        let previous = saveActionAttempt
        let attempt = SaveActionAttempt()
        saveActionAttempt = attempt
        defer { saveActionAttempt = previous }
        action()
        return attempt.failure
    }

    func retryingTransientOperation<Value>(
        _ operation: @MainActor () async -> Value,
        while shouldRetry: (Value) -> Bool,
    ) async -> Value? {
        let generation = currentSave.sessionGeneration
        var delay = SaveRetryPolicy.initialDelay
        while !Task.isCancelled, currentSave.sessionGeneration == generation {
            let result = await operation()
            guard !Task.isCancelled, currentSave.sessionGeneration == generation else { return nil }
            guard shouldRetry(result) else { return result }
            do { try await Task.sleep(for: .seconds(delay)) } catch { return nil }
            delay = SaveRetryPolicy.nextDelay(after: delay)
        }
        return nil
    }
}
