import Foundation

public enum PlayerSaveReconcileOutcome: Equatable {
    case keepLocal
    case applyRemote(PlayerSave)
    case uploadLocal
    case applyMerged(PlayerSave)
}

public enum PlayerSaveReconciler {
    public static func reconcile(local: PlayerSave?, remote: RemotePlayerSave?) -> PlayerSaveReconcileOutcome {
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
            let merged = PlayerSaveMerger.merge(local, remote.save)
            if merged == local {
                return .uploadLocal
            }
            return .applyMerged(merged)
        case (nil, nil):
            return .keepLocal
        }
    }
}
