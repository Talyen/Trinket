import Foundation
import Observation
import os

@MainActor
@Observable
public final class PlayerSaveSyncCoordinator {
    public private(set) var status: PlayerSaveSyncStatus = .idle

    private let sync: any PlayerSaveSyncing
    private let uploadDebounceInterval: Duration
    private weak var playerSaveStore: PlayerSaveStore?
    private var uploadTask: Task<Void, Never>?
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
        uploadDebounceInterval: Duration = .seconds(2)
    ) {
        self.sync = sync
        self.uploadDebounceInterval = uploadDebounceInterval
        self.playerSaveStore = playerSaveStore
        playerSaveStore.onLocalSave = { [weak self] save in
            self?.scheduleUpload(for: save)
        }
    }

    public func start() async {
        await reconcileOnLaunch()
        await registerSubscriptionIfNeeded()
    }

    public func pullAndReconcile() async {
        await reconcileOnLaunch()
    }

    public func syncNow() async {
        await reconcileOnLaunch()
    }

    public func uploadImmediately(_ save: PlayerSave) async {
        pendingUploadSave = save
        uploadTask?.cancel()
        await processUploadQueue()
    }

    private func reconcileOnLaunch() async {
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
            let outcome = PlayerSaveReconciler.reconcile(local: local, remote: remote)

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

    private func scheduleUpload(for save: PlayerSave) {
        guard !isApplyingRemoteSave else { return }

        pendingUploadSave = save
        uploadTask?.cancel()
        let debounceInterval = uploadDebounceInterval
        uploadTask = Task { [weak self] in
            try? await Task.sleep(for: debounceInterval)
            guard !Task.isCancelled else { return }
            await self?.processUploadQueue()
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

        let merged = PlayerSaveMerger.merge(local, remote.save)
        applyRemoteSave(merged)
        lastKnownRemoteChangeTag = remote.recordChangeTag

        do {
            let newTag = try await sync.upload(merged, replacingRecordChangeTag: remote.recordChangeTag)
            lastKnownRemoteChangeTag = newTag
            status = .upToDate
        } catch {
            logger.error("Upload failed after merge: \(error.localizedDescription, privacy: .public)")
            status = .offline
        }
    }

    private func applyRemoteSave(_ remoteSave: PlayerSave) {
        guard let playerSaveStore else { return }
        isApplyingRemoteSave = true
        playerSaveStore.applyRemoteSave(remoteSave)
        isApplyingRemoteSave = false
    }
}
