import Foundation
import Observation
import os

public enum PlayerSaveSessionPhase: Equatable {
    case bootstrapping
    case active
    case closed
}

@MainActor
@Observable
public final class PlayerSaveSyncCoordinator {
    public private(set) var status: PlayerSaveSyncStatus = .idle
    public private(set) var sessionPhase: PlayerSaveSessionPhase = .closed

    /// Returns whether a battle is currently in progress on the active session.
    public var hasActiveBattle: () -> Bool = { false }

    /// Called when a remote save with a higher session generation replaces local progress.
    public var onSessionSuperseded: (() -> Void)?

    private let sync: any PlayerSaveSyncing
    private weak var playerSaveStore: PlayerSaveStore?
    private var pendingUploadSave: PlayerSave?
    private var isProcessingUploads = false
    private var isApplyingRemoteSave = false
    private var deferredRemoteReconcile = false
    private var reconcileInFlight: Task<Bool, Never>?
    private var lastKnownRemoteChangeTag: String?
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "CloudSync"
    )

    public init(
        sync: any PlayerSaveSyncing,
        playerSaveStore: PlayerSaveStore
    ) {
        self.sync = sync
        self.playerSaveStore = playerSaveStore
        playerSaveStore.onLocalSave = { [weak self] save in
            guard let self, !isApplyingRemoteSave else { return }
            pendingUploadSave = save
        }
    }

    public func activateSession(subscribeToChanges: Bool) async {
        guard sessionPhase != .active else { return }

        sessionPhase = .bootstrapping
        flushStoreIfNeeded()
        _ = await reconcileOnce()
        await claimSessionLease()
        sessionPhase = .active

        guard subscribeToChanges else { return }
        await registerSubscriptionIfNeeded()
        await retryPendingUploadIfNeeded()
    }

    public func reconcileForegroundIfSafe() async {
        guard sessionPhase == .active, !hasActiveBattle() else { return }
        flushStoreIfNeeded()
        _ = await reconcileOnce()
    }

    /// Fetches and reconciles remote changes after a CloudKit push notification.
    public func reconcileFromRemoteNotification() async -> Bool {
        guard let playerSaveStore else { return false }
        flushStoreIfNeeded()

        if sessionPhase != .active {
            await activateSession(subscribeToChanges: true)
        }
        guard sessionPhase == .active else { return false }

        let saveBefore = playerSaveStore.currentSave
        let appliedRemote = await reconcileOnce()
        return appliedRemote || playerSaveStore.currentSave != saveBefore
    }

    /// Reconciles any remote save deferred while a battle was active.
    public func onBattleEnded() async {
        guard deferredRemoteReconcile, sessionPhase == .active else { return }
        let applied = await reconcileOnce()
        if applied || status == .upToDate {
            deferredRemoteReconcile = false
        }
    }

    /// Ends the active session, checkpoints cloud state, and releases the lease.
    public func closeSession() async {
        guard sessionPhase == .active else { return }

        flushStoreIfNeeded()
        await checkpointUploadIfNeeded()
        sessionPhase = .closed
    }

    public func checkpointUploadIfNeeded() async {
        guard sessionPhase == .active, let playerSaveStore else { return }
        flushStoreIfNeeded()
        await retryPendingUploadIfNeeded()
        await scheduleUpload(playerSaveStore.currentSave)
    }

    private func retryPendingUploadIfNeeded() async {
        guard let pendingUploadSave else { return }
        await scheduleUpload(pendingUploadSave)
    }

    private func flushStoreIfNeeded() {
        playerSaveStore?.flushPendingPersistIfNeeded()
    }

    private func claimSessionLease() async {
        guard let playerSaveStore else { return }

        flushStoreIfNeeded()
        do {
            try playerSaveStore.performBatchMutation { save in
                save.sessionGeneration &+= 1
            }
        } catch {
            logger.error(
                "Failed to claim session lease: \(error.localizedDescription, privacy: .public)"
            )
            return
        }

        await scheduleUpload(playerSaveStore.currentSave)
    }

    private func reconcileOnce() async -> Bool {
        if let reconcileInFlight {
            return await reconcileInFlight.value
        }

        let task = Task { @MainActor [weak self] () -> Bool in
            guard let self, let playerSaveStore else { return false }

            status = .syncing
            guard await guardAccountAvailable() else { return false }

            do {
                let remote = try await sync.fetchRemoteSave()
                let local = playerSaveStore.currentSave
                if let remote {
                    lastKnownRemoteChangeTag = remote.recordChangeTag
                }

                if !playerSaveStore.loadedFromDisk, let remote {
                    return applyRemoteSaveIfSafe(remote.save)
                }

                return await applyReconcileOutcome(
                    PlayerSaveMerger.reconcile(local: local, remote: remote),
                    local: local
                )
            } catch {
                logger.error("Reconcile failed: \(error.localizedDescription, privacy: .public)")
                status = .upToDate
                return false
            }
        }
        reconcileInFlight = task
        defer { reconcileInFlight = nil }
        return await task.value
    }

    @discardableResult
    private func applyReconcileOutcome(
        _ outcome: PlayerSaveReconcileOutcome,
        local: PlayerSave
    ) async -> Bool {
        switch outcome {
        case .keepLocal:
            status = .upToDate
            return false
        case let .applyRemote(remoteSave):
            return applyRemoteSaveIfSafe(remoteSave)
        case .uploadLocal:
            guard let playerSaveStore else { return false }
            await scheduleUpload(playerSaveStore.currentSave)
            return false
        case let .applyMerged(mergedSave):
            guard applyRemoteSaveIfSafe(mergedSave) else { return false }
            await scheduleUpload(mergedSave)
            return true
        }
    }

    @discardableResult
    private func applyRemoteSaveIfSafe(_ remoteSave: PlayerSave) -> Bool {
        guard let playerSaveStore else { return false }
        let superseded = remoteSave.sessionGeneration > playerSaveStore.currentSave.sessionGeneration
        if hasActiveBattle(), !superseded {
            deferredRemoteReconcile = true
            status = .upToDate
            return false
        }
        applyRemoteSave(remoteSave, superseded: superseded)
        status = .upToDate
        return true
    }

    private func guardAccountAvailable() async -> Bool {
        switch await sync.accountStatus() {
        case .available:
            return true
        case let .unavailable(message):
            logger.info("iCloud unavailable: \(message, privacy: .public)")
            status = .upToDate
            return false
        }
    }

    private func registerSubscriptionIfNeeded() async {
        guard await guardAccountAvailable() else { return }

        do {
            try await sync.subscribeToChanges()
        } catch {
            logger.error("Subscription failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleUpload(_ save: PlayerSave) async {
        if let pending = pendingUploadSave, pending.modifiedAt > save.modifiedAt {
            return
        }
        pendingUploadSave = save
        guard !isProcessingUploads else { return }

        isProcessingUploads = true
        defer { isProcessingUploads = false }

        while let save = pendingUploadSave {
            pendingUploadSave = nil
            let succeeded = await performUpload(save)
            if !succeeded {
                pendingUploadSave = save
                break
            }
        }
    }

    @discardableResult
    private func performUpload(_ save: PlayerSave) async -> Bool {
        status = .syncing
        guard await guardAccountAvailable() else { return false }

        do {
            let newTag = try await sync.upload(save, replacingRecordChangeTag: lastKnownRemoteChangeTag)
            lastKnownRemoteChangeTag = newTag
            status = .upToDate
            return true
        } catch let error as PlayerSaveSyncError {
            switch error {
            case let .recordConflict(remote):
                await resolveUploadConflict(remote: remote)
                return status == .upToDate
            }
        } catch {
            logger.error("Upload failed: \(error.localizedDescription, privacy: .public)")
            status = .upToDate
            return false
        }
    }

    private func resolveUploadConflict(remote: RemotePlayerSave) async {
        guard let playerSaveStore else { return }
        flushStoreIfNeeded()
        let liveLocal = playerSaveStore.currentSave

        let authoritative = PlayerSaveMerger.pickAuthoritative(local: liveLocal, remote: remote.save)
        let superseded = authoritative.sessionGeneration > liveLocal.sessionGeneration

        if hasActiveBattle(), !superseded {
            deferredRemoteReconcile = true
            status = .upToDate
            return
        }

        applyRemoteSave(authoritative, superseded: superseded)
        lastKnownRemoteChangeTag = remote.recordChangeTag

        do {
            let newTag = try await sync.upload(authoritative, replacingRecordChangeTag: remote.recordChangeTag)
            lastKnownRemoteChangeTag = newTag
            status = .upToDate
        } catch {
            logger.error("Upload failed after authority resolution: \(error.localizedDescription, privacy: .public)")
            status = .upToDate
            pendingUploadSave = playerSaveStore.currentSave
        }
    }

    private func applyRemoteSave(_ remoteSave: PlayerSave, superseded: Bool = false) {
        guard let playerSaveStore else { return }
        let saveBeforeApply = playerSaveStore.currentSave
        isApplyingRemoteSave = true
        do {
            try playerSaveStore.applyRemoteSave(remoteSave)
        } catch {
            logger.error("Failed to apply remote save locally: \(error.localizedDescription, privacy: .public)")
            status = .upToDate
        }
        isApplyingRemoteSave = false

        if superseded {
            onSessionSuperseded?()
        }

        if playerSaveStore.currentSave.modifiedAt > saveBeforeApply.modifiedAt {
            pendingUploadSave = playerSaveStore.currentSave
        }
    }
}
