struct PendingDeferredSave {
    let rollbackSnapshot: PlayerSave
    private(set) var slices: PlayerSaveSlice

    init(snapshot: PlayerSave, slices: PlayerSaveSlice) {
        rollbackSnapshot = snapshot
        self.slices = slices
    }

    mutating func include(_ slices: PlayerSaveSlice) {
        self.slices.formUnion(slices)
    }
}

@MainActor
extension PlayerSaveStore {
    public func flushPendingPersistence() {
        deferredSaveTask?.cancel()
        deferredSaveTask = nil
        guard pendingDeferredSave != nil || pendingSaveRecovery?.hasPendingSave == true else { return }
        persistDeferredSave(logging: "Failed to flush deferred player progress")
    }

    private func persistDeferredSave(logging message: String) {
        do {
            try saveGraph()
            clearPendingDeferredPersistence()
        } catch {
            notePersistenceFailure(error, logging: message)
            rollbackPendingMutationIfNeeded()
        }
    }

    func scheduleDeferredSave() {
        deferredSaveTask?.cancel()
        deferredSaveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            persistDeferredSave(logging: "Failed deferred player progress save")
        }
    }

    private func rollbackPendingMutationIfNeeded() {
        guard let pendingDeferredSave else { return }
        restoreSnapshot(pendingDeferredSave.rollbackSnapshot, slices: pendingDeferredSave.slices)
        clearPendingDeferredPersistence()
    }

    func clearPendingDeferredPersistence() {
        deferredSaveTask?.cancel()
        deferredSaveTask = nil
        pendingDeferredSave = nil
    }
}
