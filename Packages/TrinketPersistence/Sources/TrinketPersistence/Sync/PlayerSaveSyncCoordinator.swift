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

    private let sync: any PlayerSaveSyncing
    private let sessionLease: any PlayerAccountSessionLeasing
    private weak var playerSaveStore: PlayerSaveStore?
    private var pendingUploadSave: PlayerSave?
    private var isProcessingUploads = false
    private var isApplyingRemoteSave = false
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
            await reconcileAtSessionStart()
        }

        sessionPhase = .active
        await registerSubscriptionIfNeeded()
    }

    public func pullAndReconcile() async {
        guard sessionPhase != .active else { return }
        sessionPhase = .bootstrapping
        await reconcileAtSessionStart()
    }

    public func syncNow() async {
        await checkpointUploadIfNeeded()
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
        guard sessionPhase == .active, !isApplyingRemoteSave else { return }
        pendingUploadSave = save
    }

    private func reconcileAtSessionStart() async {
        guard let playerSaveStore else { return }

        status = .syncing

        switch await sync.accountStatus() {
        case .available:
            break
        case let .unavailable(message):
            status = .iCloudUnavailable(message)
            return
        }

        do {
            let local = playerSaveStore.currentSave
            let remote = try await sync.fetchRemoteSave()
            if let remote {
                lastKnownRemoteChangeTag = remote.recordChangeTag
            }
            let outcome = PlayerSaveSessionAuthority.reconcile(local: local, remote: remote)

            switch outcome {
            case .keepLocal:
                status = .upToDate
            case let .applyRemote(remoteSave):
                applyRemoteSave(remoteSave)
                status = .upToDate
            case .uploadLocal:
                await enqueueUpload(local)
            case let .applyMerged(mergedSave):
                applyRemoteSave(mergedSave)
                await enqueueUpload(mergedSave)
            }
        } catch {
            logger.error("Reconcile failed: \(error.localizedDescription, privacy: .public)")
            status = .error("Playing offline on this device.")
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
                await resolveUploadConflict(local: save, remote: remote)
            }
        } catch {
            logger.error("Upload failed: \(error.localizedDescription, privacy: .public)")
            status = .offline
        }
    }

    private func resolveUploadConflict(local: PlayerSave, remote: RemotePlayerSave) async {
        guard let playerSaveStore else { return }

        let authoritative = PlayerSaveSessionAuthority.pickAuthoritative(local: local, remote: remote.save)
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
        isApplyingRemoteSave = true
        do {
            try playerSaveStore.applyRemoteSave(remoteSave)
        } catch {
            logger.error("Failed to apply remote save locally: \(error.localizedDescription, privacy: .public)")
            status = .error("Could not apply cloud save on this device.")
        }
        isApplyingRemoteSave = false
    }
}
