import BattleEngine
import Foundation
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

    static func resumable(
        track: MusicTrack,
        contextKind: MusicTrackKind,
        stageID: String?,
        enemyID: String?,
    ) -> Self {
        Self(
            track: track,
            resumeKey: MusicResumeKey(
                contextKind: contextKind,
                stageID: stageID,
                enemyID: enemyID,
                trackID: track.id,
            ),
        )
    }
}

enum MusicRoute: Equatable {
    case silence(preservingPosition: Bool)
    case track(MusicPlaybackRequest)

    static func resolve(
        selectedTab: AppTab,
        activeBattle: BattleRunConfiguration?,
        sceneIsActive: Bool,
        musicVolume: Double,
        currentDate: Date = Date(),
    ) -> Self {
        guard sceneIsActive, musicVolume > 0 else {
            return .silence(preservingPosition: true)
        }

        guard selectedTab == .play else {
            return menuTrack(currentDate: currentDate)
        }

        if let activeBattle, let enemyID = activeBattle.enemy?.id {
            return encounter(enemyID: enemyID, currentDate: currentDate)
        }

        return menuTrack(currentDate: currentDate)
    }

    /// Menu rotates through the catalog once per calendar day so the curated
    /// alternates are actually heard; the pick is stable within the day.
    private static func menuTrack(currentDate: Date) -> Self {
        guard !MusicCatalog.menuTrackIDs.isEmpty else {
            return .silence(preservingPosition: false)
        }
        let day = Calendar.current.dateComponents([.year, .month, .day], from: currentDate)
        let seed = "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
        let trackID = MusicCatalog.menuTrackIDs[stableIndex(for: seed, count: MusicCatalog.menuTrackIDs.count)]
        guard let track = MusicCatalog.track(matching: trackID) else {
            return .silence(preservingPosition: false)
        }

        return .track(
            MusicPlaybackRequest.resumable(
                track: track,
                contextKind: .menu,
                stageID: nil,
                enemyID: nil,
            ),
        )
    }

    /// Only boss fights get a specific track. Every other battle resolves to the
    /// same stable battle track for a given enemy, regardless of mode.
    private static func encounter(enemyID: String, currentDate: Date) -> Self {
        if let bossTrackID = MusicCatalog.bossTrackIDByEnemyID[enemyID],
           let bossTrack = MusicCatalog.track(matching: bossTrackID) {
            return .track(
                MusicPlaybackRequest.resumable(
                    track: bossTrack,
                    contextKind: .boss,
                    stageID: nil,
                    enemyID: enemyID,
                ),
            )
        }

        guard let track = normalBattleTrack(enemyID: enemyID) else {
            return menuTrack(currentDate: currentDate)
        }

        return .track(
            MusicPlaybackRequest.resumable(
                track: track,
                contextKind: .battle,
                stageID: nil,
                enemyID: enemyID,
            ),
        )
    }

    private static func normalBattleTrack(enemyID: String) -> MusicTrack? {
        guard !MusicCatalog.battleTrackIDs.isEmpty else { return nil }

        let index = stableIndex(for: enemyID, count: MusicCatalog.battleTrackIDs.count)
        let trackID = MusicCatalog.battleTrackIDs[index]
        return MusicCatalog.track(matching: trackID)
    }

    /// Hand-rolled DJB2 because Swift.Hasher is per-launch randomized; the same
    /// enemy must resolve to the same battle track across launches.
    private static func stableIndex(for seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }

        var hash = UInt64(5381)
        for byte in seed.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return Int(hash % UInt64(count))
    }
}
