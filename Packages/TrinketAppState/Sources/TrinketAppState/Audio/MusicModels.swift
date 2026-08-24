import Foundation
import TrinketBattleRuntime
import TrinketContent

struct MusicResumeKey: Hashable {
    let contextKind: MusicTrackKind
    let stageID: String?
    let enemyID: String?
    let trackID: String
}

struct MusicPlaybackRequest: Equatable {
    let track: MusicTrack
    let resumeKey: MusicResumeKey
    let shouldResume: Bool

    static func resumable(
        track: MusicTrack,
        contextKind: MusicTrackKind,
        stageID: String?,
        enemyID: String?
    ) -> Self {
        Self(
            track: track,
            resumeKey: MusicResumeKey(
                contextKind: contextKind,
                stageID: stageID,
                enemyID: enemyID,
                trackID: track.id
            ),
            shouldResume: true
        )
    }
}

enum MusicRoute: Equatable {
    case silence(preservingPosition: Bool)
    case track(MusicPlaybackRequest)

    static func resolve(
        selectedTab: AppTab,
        activeBattle: BattleRunConfiguration?,
        battleStageID: String? = nil,
        sceneIsActive: Bool,
        musicVolume: Double
    ) -> Self {
        guard sceneIsActive, musicVolume > 0 else {
            return .silence(preservingPosition: true)
        }

        guard selectedTab == .play else {
            return menuTrack()
        }

        if let activeBattle, let enemyID = activeBattle.enemy?.id {
            return encounter(stageID: battleStageID, enemyID: enemyID)
        }

        return menuTrack()
    }

    private static func menuTrack() -> Self {
        guard let trackID = MusicCatalog.menuTrackIDs.first,
              let track = MusicCatalog.track(matching: trackID)
        else {
            return .silence(preservingPosition: false)
        }

        return .track(
            MusicPlaybackRequest.resumable(
                track: track,
                contextKind: .menu,
                stageID: nil,
                enemyID: nil
            )
        )
    }

    private static func encounter(stageID: String?, enemyID: String) -> Self {
        if let bossTrackID = MusicCatalog.bossTrackIDByEnemyID[enemyID],
           let bossTrack = MusicCatalog.track(matching: bossTrackID) {
            return .track(
                MusicPlaybackRequest.resumable(
                    track: bossTrack,
                    contextKind: .boss,
                    stageID: stageID,
                    enemyID: enemyID
                )
            )
        }

        guard let track = normalBattleTrack(stageID: stageID, enemyID: enemyID) else {
            return menuTrack()
        }

        return .track(
            MusicPlaybackRequest.resumable(
                track: track,
                contextKind: .battle,
                stageID: stageID,
                enemyID: enemyID
            )
        )
    }

    private static func normalBattleTrack(stageID: String?, enemyID: String) -> MusicTrack? {
        guard !MusicCatalog.battleTrackIDs.isEmpty else { return nil }

        let seed = [stageID, enemyID].compactMap(\.self).joined(separator: ":")
        let index = stableIndex(for: seed, count: MusicCatalog.battleTrackIDs.count)
        let trackID = MusicCatalog.battleTrackIDs[index]
        return MusicCatalog.track(matching: trackID)
    }

    private static func stableIndex(for seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }

        var hash = UInt64(5381)
        for byte in seed.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return Int(hash % UInt64(count))
    }
}
