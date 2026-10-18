import Foundation
import os

@MainActor
public final class PlayerSaveCloudSync {
    private weak var store: PlayerSaveStore?
    private let transport: any CloudSaveTransport
    private let reconcile: @Sendable (CloudSaveRequest, CloudServerSave?) async throws -> CloudSaveReconciler.Resolution
    private var synchronization: (id: UUID, work: Task<Bool, Never>)?
    private let logger = Logger(subsystem: PlayerSaveDefaults.loggingSubsystem, category: "CloudSave")

    init(
        store: PlayerSaveStore,
        transport: any CloudSaveTransport,
        reconcile: @escaping @Sendable (CloudSaveRequest, CloudServerSave?) async throws -> CloudSaveReconciler.Resolution = {
            try Task.checkCancellation()
            let resolution = try CloudSaveReconciler.resolve($0, against: $1)
            try Task.checkCancellation()
            return resolution
        },
    ) {
        self.store = store
        self.transport = transport
        self.reconcile = reconcile
    }

    @discardableResult
    public func synchronize() async -> Bool {
        let pending: (id: UUID, work: Task<Bool, Never>)
        if let synchronization {
            pending = synchronization
        } else {
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
            pending = (UUID(), work)
            synchronization = pending
        }
        let result = await pending.work.value
        if synchronization?.id == pending.id {
            synchronization = nil
        }
        return result
    }

    public func accountDidChange() {
        synchronization?.work.cancel()
        synchronization = nil
    }

    private func synchronizeUntilCurrent() async throws {
        guard let store, !store.isPersistenceDegraded else { throw CloudSaveError.unavailable }
        store.flushPendingPersistence()
        let accountID = try await transport.accountID()
        try Task.checkCancellation()
        try await bind(accountID, in: store)
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
            let server = try await transport.fetchHead(accountID: accountID)
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
                guard let result = try await reconcileAndCommit(request, against: server, accountID: accountID, in: store)
                else { continue }
                if try await finish(request, receipt: result.receipt, server: result.server, accountID: accountID, in: store) {
                    return
                }
            } catch CloudSaveError.conflict {
                try await waitBeforeRetry(after: attempt)
                continue
            }
        }
        throw CloudSaveError.unavailable
    }

    private func reconcileAndCommit(
        _ request: CloudSaveRequest, against server: CloudServerSave?, accountID: String, in store: PlayerSaveStore,
    ) async throws -> (server: CloudServerSave, receipt: CloudSaveReceipt)? {
        var server = server
        if let existing = server {
            server = try await transport.refreshTime(accountID: accountID, head: existing)
        }
        try Task.checkCancellation()
        let resolution = try await reconcile(request, server)
        try Task.checkCancellation()
        // Planning yields to local play and account changes. New local
        // earnings may extend this request's frozen prefix; replacing
        // the account or pending request makes the result obsolete.
        guard store.cloudDeviceState.activeAccountID == accountID else { throw CloudSaveError.accountChanged }
        guard store.cloudDeviceState.account.pending?.id == request.id else { return nil }
        let committed = try await transport.commit(
            accountID: accountID, replacing: server,
            head: resolution.head, receipt: resolution.receipt, backups: resolution.backups,
        )
        return (committed, resolution.receipt)
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
        try Task.checkCancellation()
        guard let transition = try CloudSaveTransitions.importRemote(
            server.head, state: store.cloudDeviceState, local: CloudSaveSnapshot(store.currentSave),
        ) else { return false }
        try Task.checkCancellation()
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
        let (state, request) = try CloudSaveTransitions.enqueue(
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
        return acknowledgement.isCurrent
    }

    private func bind(_ accountID: String?, in store: PlayerSaveStore) async throws {
        try Task.checkCancellation()
        guard let transition = try CloudSaveTransitions.bind(
            accountID, state: store.cloudDeviceState, local: CloudSaveSnapshot(store.currentSave),
        ) else { return }
        try Task.checkCancellation()
        guard try await apply(transition, in: store) else { throw CloudSaveError.conflict }
    }
}
