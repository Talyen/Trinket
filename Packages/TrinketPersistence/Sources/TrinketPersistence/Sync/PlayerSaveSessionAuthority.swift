import Foundation

/// Picks a single authoritative save snapshot at session start.
/// Avoids field-wise merge except when both sides share generation and timestamp.
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
        switch compare(local, remote) {
        case .orderedSame:
            return PlayerSaveMerger.merge(local, remote)
        case .orderedAscending:
            return remote
        case .orderedDescending:
            return local
        }
    }

    private static func reconcileBoth(local: PlayerSave, remote: RemotePlayerSave) -> PlayerSaveReconcileOutcome {
        switch compare(local, remote.save) {
        case .orderedSame:
            let merged = PlayerSaveMerger.merge(local, remote.save)
            if merged == local {
                return .uploadLocal
            }
            return .applyMerged(merged)
        case .orderedAscending:
            return .applyRemote(remote.save)
        case .orderedDescending:
            return .uploadLocal
        }
    }

    private static func compare(_ local: PlayerSave, _ remote: PlayerSave) -> ComparisonResult {
        if local.sessionGeneration != remote.sessionGeneration {
            return local.sessionGeneration < remote.sessionGeneration ? .orderedAscending : .orderedDescending
        }
        if local.modifiedAt == remote.modifiedAt {
            return .orderedSame
        }
        return local.modifiedAt < remote.modifiedAt ? .orderedAscending : .orderedDescending
    }
}
