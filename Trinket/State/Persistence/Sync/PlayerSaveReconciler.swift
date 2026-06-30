import Foundation

enum PlayerSaveReconcileOutcome: Equatable {
    case keepLocal
    case applyRemote(PlayerSave)
    case uploadLocal
}

enum PlayerSaveReconciler {
    static func reconcile(local: PlayerSave?, remote: RemotePlayerSave?) -> PlayerSaveReconcileOutcome {
        switch (local, remote) {
        case let (local?, nil):
            return .uploadLocal
        case let (nil, remote?):
            return .applyRemote(remote.save)
        case let (local?, remote?):
            if remote.modifiedAt > local.modifiedAt {
                return .applyRemote(remote.save)
            }
            if local.modifiedAt > remote.modifiedAt {
                return .uploadLocal
            }
            return .keepLocal
        case (nil, nil):
            return .keepLocal
        }
    }
}
