import Foundation

public enum PlayerSaveReconcileOutcome: Equatable {
    case keepLocal
    case applyRemote(PlayerSave)
    case uploadLocal
    case applyMerged(PlayerSave)
}

/// Picks a single authoritative save snapshot at session start.
/// Field-wise merge runs when both sides share a session generation.
public enum PlayerSaveSessionAuthority {
    public static func reconcile(local: PlayerSave?, remote: RemotePlayerSave?) -> PlayerSaveReconcileOutcome {
        switch (local, remote) {
        case let (local?, nil):
            return .uploadLocal
        case let (nil, remote?):
            return .applyRemote(remote.save)
        case let (local?, remote?):
            return reconcileBoth(local: local, remote: remote)
        case (nil, nil):
            return .keepLocal
        }
    }

    public static func pickAuthoritative(local: PlayerSave, remote: PlayerSave) -> PlayerSave {
        if local.sessionGeneration != remote.sessionGeneration {
            return local.sessionGeneration < remote.sessionGeneration ? remote : local
        }
        return PlayerSaveMerger.merge(local, remote)
    }

    private static func reconcileBoth(local: PlayerSave, remote: RemotePlayerSave) -> PlayerSaveReconcileOutcome {
        if local.sessionGeneration != remote.save.sessionGeneration {
            return local.sessionGeneration < remote.save.sessionGeneration
                ? .applyRemote(remote.save)
                : .uploadLocal
        }

        if local == remote.save {
            return .keepLocal
        }

        let merged = PlayerSaveMerger.merge(local, remote.save)
        if merged == local {
            return merged == remote.save ? .keepLocal : .uploadLocal
        }
        if merged == remote.save {
            return .applyRemote(remote.save)
        }
        return .applyMerged(merged)
    }
}
