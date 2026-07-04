import Foundation
import TrinketContent


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
