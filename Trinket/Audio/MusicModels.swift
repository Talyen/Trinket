import Foundation

enum MusicTrackKind: String, Hashable {
    case menu
    case battle
    case boss
}

struct MusicTrack: Identifiable, Hashable {
    let id: String
    let kind: MusicTrackKind
    let resourceName: String
    let fileExtension: String
    let bossEnemyID: String
    let isLooping: Bool
    let volumeGain: Double

    var resolvedBossEnemyID: String? {
        bossEnemyID.isEmpty ? nil : bossEnemyID
    }
}

struct BattleMusicPreview: Equatable, Identifiable {
    let stageID: String
    let enemyID: String

    var id: String {
        "\(stageID):\(enemyID)"
    }
}

enum MusicContextKind: Hashable {
    case menu
    case battle
    case boss
}

struct MusicResumeKey: Hashable {
    let contextKind: MusicContextKind
    let stageID: String?
    let enemyID: String?
    let trackID: String
}

struct MusicPlaybackRequest: Equatable {
    let track: MusicTrack
    let resumeKey: MusicResumeKey
    let shouldResume: Bool
}

enum MusicRoute: Equatable {
    case silence(preservingPosition: Bool)
    case track(MusicPlaybackRequest)
}

extension MusicCatalog {
    static var tracksByID: [String: MusicTrack] {
        Dictionary(uniqueKeysWithValues: allTracks.map { ($0.id, $0) })
    }

    static func track(matching id: String) -> MusicTrack? {
        tracksByID[id]
    }
}
