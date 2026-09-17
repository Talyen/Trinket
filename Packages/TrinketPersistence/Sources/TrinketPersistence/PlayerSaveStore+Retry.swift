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
    /// reset/account boundaries. The clear→action→check sequence is safe
    /// against concurrent keys: `action` is synchronous with no suspension
    /// between clear and check, so tasks can only interleave at `sleep`.
    ///
    /// Failure contract: `action` signals failure by leaving a retryable
    /// `lastPersistenceError` (see `PlayerSavePersistenceError.isRetryable`)
    /// behind — typically by running a `persistBatch`/`persistTransaction`
    /// that records its own failure. A cleared error means success.
    func retrySaveAction(key: String, action: @escaping @MainActor () -> Void) {
        let generation = currentSave.sessionGeneration
        let key = "\(generation):\(key)"
        guard let error = lastPersistenceError, error.isRetryable, saveActionRetries[key] == nil else { return }
        isRetryingSaveAction = true
        saveActionRetries[key] = Task { @MainActor [weak self] in
            var delay = SaveRetryPolicy.initialDelay
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(delay)) } catch { break }
                guard let self, currentSave.sessionGeneration == generation else { break }
                lastPersistenceError = nil
                action()
                guard lastPersistenceError?.isRetryable == true else { break }
                delay = SaveRetryPolicy.nextDelay(after: delay)
            }
            self?.saveActionRetries[key] = nil
            self?.isRetryingSaveAction = !(self?.saveActionRetries.isEmpty ?? true)
        }
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
            guard !shouldRetry(result) else {
                do { try await Task.sleep(for: .seconds(delay)) } catch { return nil }
                delay = SaveRetryPolicy.nextDelay(after: delay)
                continue
            }
            return result
        }
        return nil
    }
}
