import Testing
@testable import TrinketContent

struct MusicLyricsTests {
    @Test func `words build within phrases and recover from gaps and backwards media time`() throws {
        let phrases = [
            MusicLyricPhrase(text: "I grow", timings: [0.5, 1, 1.2, 2]),
            MusicLyricPhrase(text: "Again", timings: [3, 4]),
        ]
        #expect(MusicLyricFrame.at(0, in: phrases) == nil)
        let first = try #require(MusicLyricFrame.at(0.5, in: phrases))
        #expect(first.phrase == 0 && first.visibleWords == 1 && first.activeWord == 0)
        let gap = try #require(MusicLyricFrame.at(1, in: phrases))
        #expect(gap.visibleWords == 1 && gap.activeWord == nil)
        let second = try #require(MusicLyricFrame.at(1.2, in: phrases))
        #expect(second.visibleWords == 2 && second.activeWord == 1)
        #expect(MusicLyricFrame.at(2, in: phrases) == nil)
        #expect(MusicLyricFrame.at(3, in: phrases)?.phrase == 1)
        #expect(MusicLyricFrame.at(0.5, in: phrases) == first)
        #expect(MusicLyricFrame.at(.nan, in: phrases) == nil)
    }
}
