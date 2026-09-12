import Foundation

public enum MusicTrackKind: String, Hashable, Sendable {
    case menu
    case battle
    case boss
}

public struct MusicTrack: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: MusicTrackKind
    public let resourceName: String
    public let fileExtension: String
    public let bossEnemyID: String
    public let isLooping: Bool
    public let volumeGain: Double
}

public extension MusicCatalog {
    static var tracksByID: [String: MusicTrack] {
        Dictionary(uniqueKeysWithValues: allTracks.map { ($0.id, $0) })
    }

    static func track(matching id: String) -> MusicTrack? {
        tracksByID[id]
    }
}
