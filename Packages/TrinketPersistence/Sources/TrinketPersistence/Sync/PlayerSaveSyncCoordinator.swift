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
    public private(set) var sessionToken: PlayerAccountSessionToken?

    /// Returns whether a battle is currently in progress on the active session.
    public var hasActiveBattle: () -> Bool = { false }

    private let sync: any PlayerSaveSyncing
    private let sessionLease: any PlayerAccountSessionLeasing
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
        playerSaveStore: PlayerSaveStore,
        sessionLease: any PlayerAccountSessionLeasing = LocalDeviceSessionLease()
    ) {
        self.sync = sync
        self.sessionLease = sessionLease
        self.playerSaveStore = playerSaveStore
        playerSaveStore.onLocalSave = { [weak self] save in
            self?.noteLocalCheckpoint(save)
        }
    }

    public func start() async {
        guard sessionPhase != .active else { return }

        if sessionToken == nil {
            do {
                sessionToken = try await sessionLease.acquireSession()
            } catch {
                logger.error("Failed to acquire account session: \(error.localizedDescription, privacy: .public)")
                status = .error("Could not start a save session on this device.")
                sessionPhase = .closed
                return
            }
        }

        if sessionPhase != .bootstrapping {
            sessionPhase = .bootstrapping
            _ = await reconcileOnce()
        }

        sessionPhase = .active
        await registerSubscriptionIfNeeded()
        if pendingUploadSave != nil {
            await processUploadQueue()
        }
    }

    public func pullAndReconcile() async {
        guard sessionPhase != .active else { return }
        sessionPhase = .bootstrapping
        _ = await reconcileOnce()
        sessionPhase = .active
    }

    public func reconcileForegroundIfSafe(hasActiveBattle: Bool) async {
        guard sessionPhase == .active, !hasActiveBattle else { return }
        _ = await reconcileOnce()
    }

    public func syncNow() async {
        await checkpointUploadIfNeeded()
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
        deferredRemoteReconcile = false
        guard sessionPhase == .active else { return }
        _ = await reconcileOnce()
    }

    /// Ends the active session, checkpoints cloud state, and releases the lease.
    public func closeSession() async {
        guard sessionPhase == .active else { return }

        playerSaveStore?.flushPendingPersistIfNeeded()
        await checkpointUploadIfNeeded()

        if let sessionToken {
            await sessionLease.releaseSession(sessionToken)
            self.sessionToken = nil
        }

        sessionPhase = .closed
    }

    public func uploadImmediately(_ save: PlayerSave) async {
        pendingUploadSave = save
        await processUploadQueue()
    }

    public func checkpointUploadIfNeeded() async {
        guard sessionPhase == .active, let playerSaveStore else { return }
        playerSaveStore.flushPendingPersistIfNeeded()
        await enqueueUpload(playerSaveStore.currentSave)
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
            guard let self else { return false }
            return await reconcileAtSessionStart()
        }
        reconcileInFlight = task
        defer { reconcileInFlight = nil }
        return await task.value
    }

    @discardableResult
    private func reconcileAtSessionStart() async -> Bool {
        guard let playerSaveStore else { return false }

        status = .syncing

        switch await sync.accountStatus() {
        case .available:
            break
        case let .unavailable(message):
            status = .iCloudUnavailable(message)
            return false
        }

        do {
            let local = playerSaveStore.currentSave
            let remote = try await sync.fetchRemoteSave()
            if let remote {
                lastKnownRemoteChangeTag = remote.recordChangeTag
            }

            if !playerSaveStore.loadedFromDisk, let remote {
                if hasActiveBattle() {
                    deferredRemoteReconcile = true
                    status = .upToDate
                    return false
                }
                applyRemoteSave(remote.save)
                status = .upToDate
                return true
            }

            let outcome = PlayerSaveSessionAuthority.reconcile(local: local, remote: remote)

            switch outcome {
            case .keepLocal:
                status = .upToDate
                return false
            case let .applyRemote(remoteSave):
                if hasActiveBattle() {
                    deferredRemoteReconcile = true
                    status = .upToDate
                    return false
                }
                applyRemoteSave(remoteSave)
                status = .upToDate
                return true
            case .uploadLocal:
                await enqueueUpload(local)
                return false
            case let .applyMerged(mergedSave):
                if hasActiveBattle() {
                    deferredRemoteReconcile = true
                    status = .upToDate
                    return false
                }
                applyRemoteSave(mergedSave)
                await enqueueUpload(mergedSave)
                return true
            }
        } catch {
            logger.error("Reconcile failed: \(error.localizedDescription, privacy: .public)")
            status = .error("Playing offline on this device.")
            return false
        }
    }

    private func registerSubscriptionIfNeeded() async {
        switch await sync.accountStatus() {
        case .available:
            break
        case let .unavailable(message):
            status = .iCloudUnavailable(message)
            return
        }

        do {
            try await sync.subscribeToChanges()
        } catch {
            logger.error("Subscription failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func enqueueUpload(_ save: PlayerSave) async {
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

        if pendingUploadSave != nil {
            await processUploadQueue()
        }
    }

    private func performUpload(_ save: PlayerSave) async {
        status = .syncing

        switch await sync.accountStatus() {
        case .available:
            break
        case let .unavailable(message):
            status = .iCloudUnavailable(message)
            return
        }

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

        let authoritative = PlayerSaveSessionAuthority.pickAuthoritative(local: liveLocal, remote: remote.save)
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
