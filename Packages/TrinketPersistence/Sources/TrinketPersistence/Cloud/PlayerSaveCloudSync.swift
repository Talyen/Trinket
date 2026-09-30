import Foundation
import os

@MainActor
public final class PlayerSaveCloudSync {
    private weak var store: PlayerSaveStore?
    private let transport: any CloudSaveTransport
    private var task: Task<Bool, Never>?
    private var taskID: UUID?
    private var lastOperationReceipt: CloudSaveReceipt?
    private(set) var requiresAuthority: Bool
    private let logger = Logger(subsystem: PlayerSaveDefaults.loggingSubsystem, category: "CloudSave")

    init(store: PlayerSaveStore, transport: any CloudSaveTransport) {
        self.store = store
        self.transport = transport
        requiresAuthority = store.cloudDeviceState.activeAccountID != nil
    }

    @discardableResult
    public func synchronize() async -> Bool {
        if let task {
            return await task.value
        }
        let id = UUID()
        taskID = id
        let work = Task { [weak self] in
            guard let self else { return false }
            do {
                try await synchronizeUntilCurrent()
                return true
            } catch {
                if !(error is CancellationError) {
                    logger.error("iCloud progress remains pending: \(String(describing: error), privacy: .public)")
                }
                return false
            }
        }
        task = work
        let completed = await work.value
        if taskID == id {
            task = nil
            taskID = nil
        }
        return completed
    }

    public func accountDidChange() {
        task?.cancel()
        task = nil
        taskID = nil
        requiresAuthority = true
    }

    /// Production actions only (`.collect`, `.upgrade`): the sync loop
    /// enqueues `.upload`/`.reset` itself, and receipts are only retained
    /// for production actions, so `perform(.upload/.reset)` always returns
    /// nil. Callers are the Homestead claim/upgrade commands.
    func perform(_ action: CloudSaveRequest.Action) async -> CloudSaveReceipt.Outcome? {
        for _ in 0 ..< 2 {
            guard let store else { return nil }
            store.flushPendingPersistence()
            if store.cloudDeviceState.account.resetRequested
                || store.cloudDeviceState.account.base?.revision.snapshot != CloudSaveSnapshot(store.currentSave) {
                guard await synchronize() else { return nil }
            }
            store.flushPendingPersistence()
            guard requiresAuthority,
                  store.cloudDeviceState.account.pending == nil,
                  !store.cloudDeviceState.account.resetRequested,
                  store.cloudDeviceState.account.base?.revision.snapshot == CloudSaveSnapshot(store.currentSave),
                  store.cloudDeviceState.activeAccountID != nil else { return nil }
            do {
                let request = try enqueue(action, in: store)
                guard await synchronize(), let receipt = lastOperationReceipt,
                      receipt.requestID == request.id,
                      store.cloudDeviceState.account.base?.epoch == receipt.epoch,
                      let sequence = store.cloudDeviceState.account.base?.authoritySequence,
                      sequence >= receipt.authoritySequence else { return nil }
                if receipt.outcome == .progressChanged {
                    continue
                }
                return receipt.outcome
            } catch {
                return nil
            }
        }
        return nil
    }

    private func synchronizeUntilCurrent() async throws {
        guard let store, !store.isPersistenceDegraded else { throw CloudSaveError.unavailable }
        store.flushPendingPersistence()
        let accountID = try await transport.accountID()
        try Task.checkCancellation()
        try await bind(accountID, in: store)
        requiresAuthority = accountID != nil
        guard let accountID else { return }

        for attempt in 0 ..< 8 {
            try Task.checkCancellation()
            guard store.cloudDeviceState.activeAccountID == accountID else { throw CloudSaveError.accountChanged }
            if store.cloudDeviceState.account.pending == nil {
                let state = store.cloudDeviceState.account
                if state.resetRequested || state.base?.revision.snapshot != CloudSaveSnapshot(store.currentSave) {
                    _ = try enqueue(state.resetRequested ? .reset : .upload, in: store)
                }
            }
            var server = try await transport.fetchHead(accountID: accountID)
            try Task.checkCancellation()
            guard store.cloudDeviceState.activeAccountID == accountID else { throw CloudSaveError.accountChanged }
            guard let request = store.cloudDeviceState.account.pending else {
                if try await importRemoteIfUnchanged(server, in: store) {
                    return
                }
                continue
            }

            if let receipt = try await transport.fetchReceipt(accountID: accountID, requestID: request.id) {
                guard let server else { throw CloudSaveError.missingHead }
                if try await finish(request, receipt: receipt, server: server, accountID: accountID, in: store) {
                    return
                }
                continue
            }
            do {
                if let existing = server {
                    server = try await transport.refreshTime(accountID: accountID, head: existing)
                }
                try Task.checkCancellation()
                let resolution = try CloudSaveReconciler.resolve(request, against: server)
                let committed = try await transport.commit(
                    accountID: accountID,
                    replacing: server,
                    head: resolution.head,
                    receipt: resolution.receipt,
                    backups: resolution.backups,
                )
                if try await finish(request, receipt: resolution.receipt, server: committed, accountID: accountID, in: store) {
                    return
                }
            } catch CloudSaveError.conflict {
                try await waitBeforeRetry(after: attempt)
                continue
            }
        }
        throw CloudSaveError.unavailable
    }

    /// Server-conflict backoff, intentionally separate from `SaveRetryPolicy`:
    /// conflicts are server-facing (short, jittered, capped low so competing
    /// devices converge quickly), while local write retries back off to 30s.
    /// Do not unify the two without CloudKit contention evidence.
    private func waitBeforeRetry(after attempt: Int) async throws {
        guard attempt < 7 else { return }
        let ceiling = min(2000, 100 << attempt)
        try await Task.sleep(for: .milliseconds(Int.random(in: (ceiling / 2) ... ceiling)))
    }

    private func importRemoteIfUnchanged(_ server: CloudServerSave?, in store: PlayerSaveStore) async throws -> Bool {
        guard let server else { throw CloudSaveError.missingHead }
        guard let transition = try CloudSaveTransitions.importRemote(
            server.head, state: store.cloudDeviceState, local: CloudSaveSnapshot(store.currentSave),
        ) else { return false }
        return try await apply(transition, in: store)
    }

    /// All external-save transitions share the same preparation and stale-state
    /// guard. The plan is computed before suspension and committed only if its
    /// source metadata and gameplay values still match.
    private func apply(_ transition: CloudSaveTransition, in store: PlayerSaveStore) async throws -> Bool {
        let replacement = transition.replacement
        let finishPreparation: (@MainActor (Bool) -> Void)? = if let replacement, transition.invalidatesSession,
                                                                 CloudSaveSnapshot(replacement) != transition.sourceSnapshot {
            try await store.prepareExternalProgress?(replacement)
        } else {
            nil
        }
        do {
            try Task.checkCancellation()
            guard transition.matches(state: store.cloudDeviceState, local: CloudSaveSnapshot(store.currentSave)) else {
                finishPreparation?(false)
                return false
            }
            if transition.state != transition.sourceState || replacement != nil {
                try store.commitCloudState(
                    transition.state, replacing: replacement, invalidatesSession: transition.invalidatesSession,
                )
            }
            finishPreparation?(true)
            return true
        } catch {
            finishPreparation?(false)
            throw error
        }
    }

    private func enqueue(_ action: CloudSaveRequest.Action, in store: PlayerSaveStore) throws -> CloudSaveRequest {
        store.flushPendingPersistence()
        let (state, request) = CloudSaveTransitions.enqueue(
            action, state: store.cloudDeviceState, local: CloudSaveSnapshot(store.currentSave), id: UUID().uuidString,
        )
        try store.commitCloudState(state)
        return request
    }

    private func finish(
        _ request: CloudSaveRequest,
        receipt: CloudSaveReceipt,
        server: CloudServerSave,
        accountID: String,
        in store: PlayerSaveStore,
    ) async throws -> Bool {
        try Task.checkCancellation()
        guard let acknowledgement = try CloudSaveTransitions.acknowledge(
            request, receipt: receipt, head: server.head, accountID: accountID,
            state: store.cloudDeviceState, local: CloudSaveSnapshot(store.currentSave),
        ), try await apply(acknowledgement.transition, in: store) else { return false }
        if let operationReceipt = acknowledgement.operationReceipt {
            lastOperationReceipt = operationReceipt
        }
        return acknowledgement.isCurrent
    }

    private func bind(_ accountID: String?, in store: PlayerSaveStore) async throws {
        guard let transition = try CloudSaveTransitions.bind(
            accountID, state: store.cloudDeviceState, local: CloudSaveSnapshot(store.currentSave),
        ) else { return }
        guard try await apply(transition, in: store) else { throw CloudSaveError.conflict }
    }
}
