import CloudKit
import Foundation
import TrinketCore

extension AppState {
    func installCloudSynchronization() {
        guard playerSave.cloudSync != nil else { return }
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
        guard let sync = playerSave.cloudSync else { return }
        while !Task.isCancelled {
            await sync.synchronize()
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                return
            }
        }
    }
}
