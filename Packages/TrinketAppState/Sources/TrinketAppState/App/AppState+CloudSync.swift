import CloudKit
import Foundation
import TrinketCore

extension AppState {
    func installCloudSynchronization() {
        // Durable-storage recovery can enable sync after bootstrap. These hooks
        // belong to the save store's lifetime, including its local-only phase.
        playerSave.onExternalProgressChange = { [weak play] in
            play?.clearTransientState()
        }
        let observer = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in
                guard let sync = self?.playerSave.cloudSync else { return }
                sync.accountDidChange()
                await sync.synchronize()
            }
        }
        cloudAccountObserver = MainActorCleanup {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func runCloudSynchronization() async {
        await runCloudSynchronization {
            try await Task.sleep(for: .seconds(30))
        }
    }

    func runCloudSynchronization(waitForNextPoll: @MainActor () async throws -> Void) async {
        while !Task.isCancelled {
            await playerSave.cloudSync?.synchronize()
            do {
                try await waitForNextPoll()
            } catch {
                return
            }
        }
    }
}
