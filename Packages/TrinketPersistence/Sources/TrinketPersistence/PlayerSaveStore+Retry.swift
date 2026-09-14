import Foundation

@MainActor
public extension PlayerSaveStore {
    func retrySaveAction(key: String, action: @escaping @MainActor () -> Void) {
        let generation = currentSave.sessionGeneration
        let key = "\(generation):\(key)"
        guard lastPersistenceError == .writeFailed, saveActionRetries[key] == nil else { return }
        isRetryingSaveAction = true
        saveActionRetries[key] = Task { @MainActor [weak self] in
            var delay = 0.25
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(delay)) } catch { break }
                guard let self, currentSave.sessionGeneration == generation else { break }
                lastPersistenceError = nil
                action()
                guard lastPersistenceError == .writeFailed else { break }
                delay = min(delay * 2, 30)
            }
            self?.saveActionRetries[key] = nil
            self?.isRetryingSaveAction = self?.saveActionRetries.isEmpty == false
        }
    }

    func retryingTransientOperation<Value>(
        _ operation: @MainActor () async -> Value,
        while shouldRetry: (Value) -> Bool,
    ) async -> Value? {
        let generation = currentSave.sessionGeneration
        var delay = 0.25
        while !Task.isCancelled, currentSave.sessionGeneration == generation {
            let result = await operation()
            guard !Task.isCancelled, currentSave.sessionGeneration == generation else { return nil }
            guard !shouldRetry(result) else {
                do { try await Task.sleep(for: .seconds(delay)) } catch { return nil }
                delay = min(delay * 2, 30)
                continue
            }
            return result
        }
        return nil
    }
}
