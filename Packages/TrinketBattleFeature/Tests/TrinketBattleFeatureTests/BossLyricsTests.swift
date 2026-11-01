import Testing
import TrinketContent
@testable import TrinketBattleFeature

struct BossLyricsTests {
    @Test func `cached lyrics follow every word boundary and media time jump`() {
        for trackID in MusicCatalog.bossTrackIDByEnemyID.values {
            guard let phrases = MusicCatalog.lyrics(for: trackID) else { continue }
            var sampler = BossLyricSampler(phrases: phrases)
            let boundaries = phrases.flatMap { $0.words.flatMap { [$0.start, $0.end] } }.sorted()
            let times = boundaries.flatMap { [$0 - 0.0001, $0, $0 + 0.0001] }
            for time in times + times.reversed() {
                #expect(sampler.frame(at: time) == MusicLyricFrame.at(time, in: phrases))
            }
            #expect(sampler.frame(at: .nan) == nil)
            #expect(sampler.frame(at: 0) == MusicLyricFrame.at(0, in: phrases))
        }
    }
}
