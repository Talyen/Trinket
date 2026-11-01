import Foundation

public struct MusicPlaybackSnapshot: Equatable, Sendable {
    public let trackID: String
    public let currentTime: TimeInterval
    public let isAudible: Bool
    public let duration: TimeInterval

    public init(trackID: String, currentTime: TimeInterval, isAudible: Bool, duration: TimeInterval = .infinity) {
        self.trackID = trackID
        self.currentTime = currentTime
        self.isAudible = isAudible
        self.duration = duration
    }
}

@MainActor
public struct BattlePresentationDependencies {
    public let readMusicPlayback: () -> MusicPlaybackSnapshot?
    public let musicPlaybackChanges: (() -> AsyncStream<Void>)?
    public let bossLyricsEnabled: () -> Bool
    public let playSFX: ([String]) -> Void
    public let warmSFX: ([String], Int) -> Void
    public let hapticsEnabled: () -> Bool
    public let rememberAutoBattlePreference: () -> Bool
    public let autoBattleEnabled: () -> Bool
    public let setAutoBattleEnabled: (Bool) -> Void

    public static let silent = Self(
        playSFX: { _ in },
        warmSFX: { _, _ in },
        hapticsEnabled: { false },
        rememberAutoBattlePreference: { false },
        autoBattleEnabled: { false },
        setAutoBattleEnabled: { _ in },
    )

    public init(
        readMusicPlayback: @escaping () -> MusicPlaybackSnapshot? = { nil },
        musicPlaybackChanges: (() -> AsyncStream<Void>)? = nil,
        bossLyricsEnabled: @escaping () -> Bool = { false },
        playSFX: @escaping ([String]) -> Void,
        warmSFX: @escaping ([String], Int) -> Void,
        hapticsEnabled: @escaping () -> Bool,
        rememberAutoBattlePreference: @escaping () -> Bool = { false },
        autoBattleEnabled: @escaping () -> Bool = { false },
        setAutoBattleEnabled: @escaping (Bool) -> Void = { _ in },
    ) {
        self.readMusicPlayback = readMusicPlayback
        self.musicPlaybackChanges = musicPlaybackChanges
        self.bossLyricsEnabled = bossLyricsEnabled
        self.playSFX = playSFX
        self.warmSFX = warmSFX
        self.hapticsEnabled = hapticsEnabled
        self.rememberAutoBattlePreference = rememberAutoBattlePreference
        self.autoBattleEnabled = autoBattleEnabled
        self.setAutoBattleEnabled = setAutoBattleEnabled
    }
}
