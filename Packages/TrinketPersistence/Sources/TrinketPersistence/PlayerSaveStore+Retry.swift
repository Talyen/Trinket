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
    /// Runs an action and retains it only if its own persistence commands fail
    /// transiently. Initial attempts and retries use the same failure boundary;
    /// `lastPersistenceError` remains a diagnostic, never a scheduling input.
    /// Nested actions own their failures independently. Keys deduplicate queued
    /// retries, and a changed save generation invalidates the retained action.
    /// `isRetry` lets the owner finish delayed feedback after a successful retry.
    @discardableResult
    func performSaveAction<Value>(
        key: String,
        _ action: @escaping @MainActor (_ isRetry: Bool) -> Value,
    ) -> Value {
        let generation = sessionGeneration
        let result = attemptSaveAction { action(false) }
        if result.failure?.isRetryable == true, sessionGeneration == generation {
            saveActionRetries.schedule(key: "\(generation):\(key)") { [weak self] in
                guard let self, sessionGeneration == generation else { return nil }
                return attemptSaveAction { action(true) }.failure
            }
        }
        return result.value
    }

    private func attemptSaveAction<Value>(_ action: () -> Value) -> (value: Value, failure: PlayerSavePersistenceError?) {
        let previous = saveActionAttempt
        let attempt = SaveActionAttempt()
        saveActionAttempt = attempt
        defer { saveActionAttempt = previous }
        let value = action()
        return (value, attempt.failure)
    }
}

@MainActor
extension PlayerSaveStore {
    /// Domain commands own their retries. Each attempt is synchronous, so reset
    /// or account replacement cannot interleave between its generation check and commit.
    /// Only the operation's typed storage failure can request another attempt.
    func retryingSaveTransaction<Value, Failure: Error>(
        _ operation: () throws -> SaveTransactionResult<Value, Failure>,
    ) async -> SaveTransactionResult<Value, Failure>? {
        let generation = sessionGeneration
        // Let the caller display pending feedback before entering the save graph.
        await Task.yield()
        var delay = SaveRetryPolicy.initialDelay
        while !Task.isCancelled, sessionGeneration == generation {
            let result: SaveTransactionResult<Value, Failure>
            do {
                result = try operation()
            } catch {
                result = .persistFailed(PlayerSavePersistenceError.mapped(error))
            }
            guard !Task.isCancelled, sessionGeneration == generation else { return nil }
            guard case let .persistFailed(error) = result, error.isRetryable else { return result }
            do { try await Task.sleep(for: .seconds(delay)) } catch { return nil }
            delay = SaveRetryPolicy.nextDelay(after: delay)
        }
        return nil
    }
}
