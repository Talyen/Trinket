import Foundation
import os

@MainActor
@Observable
final class PlayerSaveSyncCoordinator {
    private(set) var status: PlayerSaveSyncStatus = .idle

    private let sync: any PlayerSaveSyncing
    private weak var playerSaveStore: PlayerSaveStore?
    private var uploadTask: Task<Void, Never>?
    private var isApplyingRemoteSave = false
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Trinket",
        category: "CloudSync"
    )

    init(sync: any PlayerSaveSyncing, playerSaveStore: PlayerSaveStore) {
        self.sync = sync
        self.playerSaveStore = playerSaveStore
        playerSaveStore.onLocalSave = { [weak self] save in
            self?.scheduleUpload(for: save)
        }
    }

    func start() async {
        await reconcileOnLaunch()
        await registerSubscriptionIfNeeded()
    }

    func pullAndReconcile() async {
        await reconcileOnLaunch()
    }

    func syncNow() async {
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

        uploadTask?.cancel()
        uploadTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.upload(save)
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

enum PlayerSaveSyncFactory {
    static func makeSyncService() -> any PlayerSaveSyncing {
        let env = AppEnvironment.shared
        if env.disableCloudSync || env.resetState {
            return LocalOnlyPlayerSaveSync()
        }
        return CloudKitPlayerSaveSync()
    }
}
