import Foundation

struct MusicDirector {
    func route(
        selectedTab: AppTab,
        preview: BattleMusicPreview?,
        activeBattle: ActiveBattleConfiguration?,
        sceneIsActive: Bool,
        musicVolume: Double
    ) -> MusicRoute {
        guard sceneIsActive, musicVolume > 0 else {
            return .silence(preservingPosition: true)
        }

        guard selectedTab == .play else {
            return menuRoute()
        }

        if let activeBattle, let enemyID = activeBattle.enemy?.id {
            return encounterRoute(stageID: activeBattle.stageID, enemyID: enemyID)
        }

        if let preview {
            return encounterRoute(stageID: preview.stageID, enemyID: preview.enemyID)
        }

        return menuRoute()
    }

    private func menuRoute() -> MusicRoute {
        guard let trackID = MusicCatalog.menuTrackIDs.first,
              let track = MusicCatalog.track(matching: trackID)
        else {
            return .silence(preservingPosition: false)
        }

        return .track(
            MusicPlaybackRequest(
                track: track,
                resumeKey: MusicResumeKey(contextKind: .menu, stageID: nil, enemyID: nil, trackID: track.id),
                shouldResume: true
            )
        )
    }

    private func encounterRoute(stageID: String?, enemyID: String) -> MusicRoute {
        if let bossTrackID = MusicCatalog.bossTrackIDByEnemyID[enemyID],
           let bossTrack = MusicCatalog.track(matching: bossTrackID) {
            return .track(
                MusicPlaybackRequest(
                    track: bossTrack,
                    resumeKey: MusicResumeKey(contextKind: .boss, stageID: stageID, enemyID: enemyID, trackID: bossTrack.id),
                    shouldResume: true
                )
            )
        }

        guard let track = normalBattleTrack(stageID: stageID, enemyID: enemyID) else {
            return menuRoute()
        }

        return .track(
            MusicPlaybackRequest(
                track: track,
                resumeKey: MusicResumeKey(contextKind: .battle, stageID: stageID, enemyID: enemyID, trackID: track.id),
                shouldResume: true
            )
        )
    }

    private func normalBattleTrack(stageID: String?, enemyID: String) -> MusicTrack? {
        guard !MusicCatalog.battleTrackIDs.isEmpty else { return nil }

        let seed = [stageID, enemyID].compactMap(\.self).joined(separator: ":")
        let index = Self.stableIndex(for: seed, count: MusicCatalog.battleTrackIDs.count)
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
