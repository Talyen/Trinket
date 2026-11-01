import Testing
import TrinketContent
@testable import TrinketBattleFeature

struct BossLyricsTests {
    @Test func `wake deadline follows word boundaries and the song loop`() throws {
        let trackID = try #require(MusicCatalog.bossTrackIDByEnemyID["the_blight_treant"])
        let phrases = try #require(MusicCatalog.lyrics(for: trackID))
        var sampler = BossLyricSampler(phrases: phrases)
        let first = try #require(phrases.first?.words.first?.start)
        _ = sampler.frame(at: first - 0.1)
        #expect(abs(sampler.delayUntilNextBoundary(at: first - 0.1, duration: 100) - 0.1) < 0.0001)
        _ = sampler.frame(at: 0)
        #expect(abs(sampler.delayUntilNextBoundary(at: 0, duration: 0.2) - 0.2) < 0.0001)
        #expect(sampler.delayUntilNextBoundary(at: .nan, duration: 100) == 1.0 / 60)
    }

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
