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
