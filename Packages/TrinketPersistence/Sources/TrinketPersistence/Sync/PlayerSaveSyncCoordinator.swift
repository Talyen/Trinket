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
            self?.noteLocalCheckpoint(save)
        }
    }

    public func start() async {
        await activateSession(subscribe: true)
    }

    public func pullAndReconcile() async {
        await activateSession(subscribe: false)
    }

    public func reconcileForegroundIfSafe() async {
        guard sessionPhase == .active, !hasActiveBattle() else { return }
        playerSaveStore?.flushPendingPersistIfNeeded()
        _ = await reconcileOnce()
    }

    /// Fetches and reconciles remote changes after a CloudKit push notification.
    public func reconcileFromRemoteNotification() async -> Bool {
        guard let playerSaveStore else { return false }
        playerSaveStore.flushPendingPersistIfNeeded()

        if sessionPhase != .active {
            await start()
        }
        guard sessionPhase == .active else { return false }

        let saveBefore = playerSaveStore.currentSave
        let appliedRemote = await reconcileOnce()
        if appliedRemote {
            return true
        }
        return playerSaveStore.currentSave != saveBefore
    }

    /// Reconciles any remote save deferred while a battle was active.
    public func onBattleEnded() async {
        guard deferredRemoteReconcile else { return }
        guard sessionPhase == .active else { return }
        let applied = await reconcileOnce()
        if applied || status == .upToDate {
            deferredRemoteReconcile = false
        }
    }

    /// Ends the active session, checkpoints cloud state, and releases the lease.
    public func closeSession() async {
        guard sessionPhase == .active else { return }

        playerSaveStore?.flushPendingPersistIfNeeded()
        await checkpointUploadIfNeeded()
        sessionPhase = .closed
    }

    public func checkpointUploadIfNeeded() async {
        guard sessionPhase == .active, let playerSaveStore else { return }
        playerSaveStore.flushPendingPersistIfNeeded()
        await scheduleUpload(playerSaveStore.currentSave)
    }

    private func activateSession(subscribe: Bool) async {
        guard sessionPhase != .active else { return }

        sessionPhase = .bootstrapping
        _ = await reconcileOnce()
        sessionPhase = .active

        guard subscribe else { return }
        await registerSubscriptionIfNeeded()
        if pendingUploadSave != nil {
            await processUploadQueue()
        }
    }

    private func noteLocalCheckpoint(_ save: PlayerSave) {
        guard !isApplyingRemoteSave else { return }
        pendingUploadSave = save
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
                status = .error("Playing offline on this device.")
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
    private func deferReconcileIfBattleActive() -> Bool {
        guard hasActiveBattle() else { return false }
        deferredRemoteReconcile = true
        status = .upToDate
        return true
    }

    @discardableResult
    private func applyRemoteSaveIfSafe(_ remoteSave: PlayerSave) -> Bool {
        if deferReconcileIfBattleActive() { return false }
        applyRemoteSave(remoteSave)
        status = .upToDate
        return true
    }

    private func guardAccountAvailable() async -> Bool {
        switch await sync.accountStatus() {
        case .available:
            return true
        case let .unavailable(message):
            status = .iCloudUnavailable(message)
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
        await processUploadQueue()
    }

    private func processUploadQueue() async {
        guard !isProcessingUploads else { return }
        isProcessingUploads = true
        defer { isProcessingUploads = false }

        while let save = pendingUploadSave {
            pendingUploadSave = nil
            await performUpload(save)
        }
    }

    private func performUpload(_ save: PlayerSave) async {
        status = .syncing
        guard await guardAccountAvailable() else { return }

        do {
            let newTag = try await sync.upload(save, replacingRecordChangeTag: lastKnownRemoteChangeTag)
            lastKnownRemoteChangeTag = newTag
            status = .upToDate
        } catch let error as PlayerSaveSyncError {
            switch error {
            case let .recordConflict(remote):
                await resolveUploadConflict(remote: remote)
            }
        } catch {
            logger.error("Upload failed: \(error.localizedDescription, privacy: .public)")
            status = .offline
        }
    }

    private func resolveUploadConflict(remote: RemotePlayerSave) async {
        guard let playerSaveStore else { return }
        playerSaveStore.flushPendingPersistIfNeeded()
        let liveLocal = playerSaveStore.currentSave

        let authoritative = PlayerSaveMerger.pickAuthoritative(local: liveLocal, remote: remote.save)

        if deferReconcileIfBattleActive() { return }

        applyRemoteSave(authoritative)
        lastKnownRemoteChangeTag = remote.recordChangeTag

        do {
            let newTag = try await sync.upload(authoritative, replacingRecordChangeTag: remote.recordChangeTag)
            lastKnownRemoteChangeTag = newTag
            status = .upToDate
        } catch {
            logger.error("Upload failed after authority resolution: \(error.localizedDescription, privacy: .public)")
            status = .offline
        }
    }

    private func applyRemoteSave(_ remoteSave: PlayerSave) {
        guard let playerSaveStore else { return }
        let saveBeforeApply = playerSaveStore.currentSave
        isApplyingRemoteSave = true
        do {
            try playerSaveStore.applyRemoteSave(remoteSave)
        } catch {
            logger.error("Failed to apply remote save locally: \(error.localizedDescription, privacy: .public)")
            status = .error("Could not apply cloud save on this device.")
        }
        isApplyingRemoteSave = false

        if playerSaveStore.currentSave.modifiedAt > saveBeforeApply.modifiedAt {
            pendingUploadSave = playerSaveStore.currentSave
        }
    }
}
