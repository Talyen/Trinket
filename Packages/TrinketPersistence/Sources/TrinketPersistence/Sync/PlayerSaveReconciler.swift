import Foundation

public enum PlayerSaveReconcileOutcome: Equatable {
    case keepLocal
    case applyRemote(PlayerSave)
    case uploadLocal
    case applyMerged(PlayerSave)
}

public enum PlayerSaveReconciler {
    public static func reconcile(local: PlayerSave?, remote: RemotePlayerSave?) -> PlayerSaveReconcileOutcome {
        PlayerSaveSessionAuthority.reconcile(local: local, remote: remote)
    }
}
