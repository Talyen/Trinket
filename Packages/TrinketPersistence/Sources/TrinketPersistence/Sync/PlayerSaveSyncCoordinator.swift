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
    private var isUploading = false
    private var pendingUploadSave: PlayerSave?
    private var isApplyingRemoteSave = false
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
            let outcome = PlayerSaveReconciler.reconcile(local: local, remote: remote)

            switch outcome {
            case .keepLocal:
                status = .upToDate
            case let .applyRemote(remoteSave):
                isApplyingRemoteSave = true
                playerSaveStore.applyRemoteSave(remoteSave)
                isApplyingRemoteSave = false
                status = .upToDate
            case .uploadLocal:
                try await sync.upload(local)
                status = .upToDate
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
            await self?.uploadPendingSaves()
        }
    }

    private func uploadPendingSaves() async {
        guard !isUploading else { return }
        isUploading = true
        defer { isUploading = false }

        while let save = pendingUploadSave {
            pendingUploadSave = nil
            await upload(save)
        }

        if pendingUploadSave != nil {
            await uploadPendingSaves()
        }
    }

    private func upload(_ save: PlayerSave) async {
        status = .syncing

        switch await sync.accountStatus() {
        case .available:
            break
        case let .unavailable(message):
            status = .iCloudUnavailable(message)
            return
        }

        do {
            try await sync.upload(save)
            status = .upToDate
        } catch {
            logger.error("Upload failed: \(error.localizedDescription, privacy: .public)")
            status = .offline
        }
    }
}
