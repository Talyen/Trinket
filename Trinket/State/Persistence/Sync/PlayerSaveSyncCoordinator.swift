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
    static func makeSyncService(
        environment: AppEnvironment = .shared,
        entitlementChecker: any CloudKitEntitlementChecking = RuntimeCloudKitEntitlementChecker(),
        cloudSyncFactory: () -> any PlayerSaveSyncing = { CloudKitPlayerSaveSync() }
    ) -> any PlayerSaveSyncing {
        let env = environment
        if env.disableCloudSync || env.resetState {
            return LocalOnlyPlayerSaveSync()
        }

        guard entitlementChecker.hasCloudKitContainer(
            identifier: CloudKitPlayerSaveSync.containerIdentifier
        ) else {
            return LocalOnlyPlayerSaveSync()
        }

        return cloudSyncFactory()
    }
}

protocol CloudKitEntitlementChecking {
    func hasCloudKitContainer(identifier: String) -> Bool
}

struct RuntimeCloudKitEntitlementChecker: CloudKitEntitlementChecking {
    private static let cloudKitServicesEntitlementKey = "com.apple.developer.icloud-services"
    private static let containerIdentifiersEntitlementKey = "com.apple.developer.icloud-container-identifiers"

    func hasCloudKitContainer(identifier: String) -> Bool {
        let entitlements = Bundle.main.signedEntitlements()
        guard
            entitlementValues(
                in: entitlements,
                for: Self.cloudKitServicesEntitlementKey
            ).contains("CloudKit"),
            entitlementValues(
                in: entitlements,
                for: Self.containerIdentifiersEntitlementKey
            ).contains(identifier)
        else {
            return false
        }

        return true
    }

    private func entitlementValues(in entitlements: [String: Any], for key: String) -> [String] {
        guard let value = entitlements[key] else { return [] }
        if let values = value as? [String] {
            return values
        }

        if let value = value as? String {
            return [value]
        }

        return []
    }
}

private extension Bundle {
    func signedEntitlements() -> [String: Any] {
        guard
            let executableURL,
            let executableData = try? Data(contentsOf: executableURL)
        else {
            return [:]
        }

        return executableData.embeddedPropertyListDictionaries().first { entitlements in
            entitlements["application-identifier"] != nil ||
                entitlements["com.apple.application-identifier"] != nil ||
                entitlements["com.apple.developer.icloud-container-identifiers"] != nil
        } ?? [:]
    }
}

private extension Data {
    func embeddedPropertyListDictionaries() -> [[String: Any]] {
        let startMarker = Data("<?xml".utf8)
        let endMarker = Data("</plist>".utf8)
        var dictionaries: [[String: Any]] = []
        var searchRange = startIndex ..< endIndex

        while
            let start = range(of: startMarker, options: [], in: searchRange),
            let end = range(of: endMarker, options: [], in: start.upperBound ..< endIndex) {
            let plistData = self[start.lowerBound ..< end.upperBound]
            if let dictionary = try? PropertyListSerialization.propertyList(
                from: plistData,
                options: [],
                format: nil
            ) as? [String: Any] {
                dictionaries.append(dictionary)
            }

            searchRange = end.upperBound ..< endIndex
        }

        return dictionaries
    }
}
