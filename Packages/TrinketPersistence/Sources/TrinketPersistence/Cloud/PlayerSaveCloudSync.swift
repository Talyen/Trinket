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
        try bind(accountID, in: store)
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
                if try importRemoteIfUnchanged(server, in: store) {
                    return
                }
                continue
            }

            if let receipt = try await transport.fetchReceipt(accountID: accountID, requestID: request.id) {
                guard let server else { throw CloudSaveError.missingHead }
                if try finish(request, receipt: receipt, server: server, accountID: accountID, in: store) {
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
                if try finish(request, receipt: resolution.receipt, server: committed, accountID: accountID, in: store) {
                    return
                }
            } catch CloudSaveError.conflict {
                try await waitBeforeRetry(after: attempt)
                continue
            }
        }
        throw CloudSaveError.unavailable
    }

    private func waitBeforeRetry(after attempt: Int) async throws {
        guard attempt < 7 else { return }
        let ceiling = min(2000, 100 << attempt)
        try await Task.sleep(for: .milliseconds(Int.random(in: (ceiling / 2) ... ceiling)))
    }

    private func importRemoteIfUnchanged(_ server: CloudServerSave?, in store: PlayerSaveStore) throws -> Bool {
        guard let server else { throw CloudSaveError.missingHead }
        var state = store.cloudDeviceState
        let current = CloudSaveSnapshot(store.currentSave)
        guard state.account.base?.revision.snapshot == current, !state.account.resetRequested else { return false }
        if state.account.base != server.head {
            state.account.base = server.head
            try store.commitCloudState(state, replacing: server.head.revision.snapshot.restored())
        }
        return true
    }

    private func enqueue(_ action: CloudSaveRequest.Action, in store: PlayerSaveStore) throws -> CloudSaveRequest {
        store.flushPendingPersistence()
        var state = store.cloudDeviceState
        let base = state.account.base
        state.counter = max(state.counter, base?.revision.clock[state.deviceID] ?? 0) + 1
        var clock = base?.revision.clock ?? [:]
        clock[state.deviceID] = state.counter
        let id = UUID().uuidString
        let request = CloudSaveRequest(
            id: id,
            action: action,
            baseEpoch: base?.epoch,
            baseRevisionID: base?.revision.id,
            authoritySequence: base?.authoritySequence ?? 0,
            revision: CloudSaveRevision(id: id, clock: clock, snapshot: CloudSaveSnapshot(store.currentSave)),
        )
        state.account.pending = request
        try store.commitCloudState(state)
        return request
    }

    private func finish(
        _ request: CloudSaveRequest,
        receipt: CloudSaveReceipt,
        server: CloudServerSave,
        accountID: String,
        in store: PlayerSaveStore,
    ) throws -> Bool {
        try Task.checkCancellation()
        var state = store.cloudDeviceState
        guard state.activeAccountID == accountID else { throw CloudSaveError.accountChanged }
        guard state.account.pending?.id == request.id else { return false }
        let sourceUnchanged = CloudSaveSnapshot(store.currentSave) == request.revision.snapshot
        state.account.pending = nil
        if sourceUnchanged {
            state.account.base = server.head
            state.account.resetRequested = false
            let isOwnChange: Bool = switch receipt.outcome {
            case .collected, .upgraded:
                server.head.revision.id == request.id
            default:
                receipt.acceptedLocalSnapshot && server.head.revision.id == request.id
            }
            try store.commitCloudState(
                state,
                replacing: server.head.revision.snapshot.restored(),
                invalidatesSession: !isOwnChange,
            )
        } else {
            if receipt.acceptedLocalSnapshot, receipt.epoch == server.head.epoch,
               server.head.revision.id == request.id {
                state.account.base = server.head
                if request.action == .reset {
                    state.account.resetRequested = false
                }
            }
            try store.commitCloudState(state)
        }
        if request.action != .upload, request.action != .reset {
            lastOperationReceipt = receipt
        }
        return sourceUnchanged
    }

    private func bind(_ accountID: String?, in store: PlayerSaveStore) throws {
        var state = store.cloudDeviceState
        guard state.activeAccountID != accountID else { return }
        let local = CloudSaveSnapshot(store.currentSave)
        if let previous = state.activeAccountID {
            state.archives[previous] = CloudAccountArchive(snapshot: local, state: state.account)
        }
        let replacement: PlayerSave?
        if let accountID {
            if !state.hasLinkedAccount {
                state.guestBackup = local
                state.account = CloudAccountState()
                replacement = nil
            } else if let archive = state.archives.removeValue(forKey: accountID) {
                if state.activeAccountID == nil {
                    state.guestBackup = local
                }
                state.account = archive.state
                replacement = try archive.snapshot.restored()
            } else {
                if state.activeAccountID == nil {
                    state.guestBackup = local
                }
                state.account = CloudAccountState()
                replacement = .fresh
            }
            state.hasLinkedAccount = true
        } else {
            state.account = CloudAccountState()
            replacement = nil
        }
        state.activeAccountID = accountID
        try store.commitCloudState(state, replacing: replacement)
    }
}
