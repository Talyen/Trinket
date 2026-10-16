import Foundation

public struct MusicLyricWord: Sendable {
    public let text: String
    public let start: TimeInterval
    public let end: TimeInterval
}

public struct MusicLyricPhrase: Sendable {
    public let words: [MusicLyricWord]

    init(text: String, timings: [TimeInterval]) {
        words = text.split(separator: " ").enumerated().map { index, word in
            MusicLyricWord(text: String(word), start: timings[index * 2], end: timings[index * 2 + 1])
        }
    }
}

public struct MusicLyricFrame: Equatable, Sendable {
    public let phrase: Int
    public let visibleWords: Int
    public let activeWord: Int?

    /// Always derive from media time so seeks, resumed playback and loops need no reset clock.
    public static func at(_ time: TimeInterval, in phrases: [MusicLyricPhrase]) -> Self? {
        guard time.isFinite,
              let phrase = phrases.firstIndex(where: {
                  guard let first = $0.words.first, let last = $0.words.last else { return false }
                  return time >= first.start && time < last.end
              }) else { return nil }
        let words = phrases[phrase].words
        return Self(
            phrase: phrase,
            visibleWords: words.prefix { $0.start <= time }.count,
            activeWord: words.firstIndex { time >= $0.start && time < $0.end },
        )
    }
}
