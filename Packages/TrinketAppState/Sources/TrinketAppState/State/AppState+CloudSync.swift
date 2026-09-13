import CloudKit
import Foundation

extension AppState {
    func installCloudSynchronization() {
        guard playerSave.cloudSync != nil else { return }
        playerSave.onExternalProgressChange = { [weak play] in
            play?.clearTransientState()
        }
        cloudAccountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in
                guard let sync = self?.playerSave.cloudSync else { return }
                sync.accountDidChange()
                await sync.synchronize()
            }
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
