import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct BossLyrics: View {
    @Environment(BattleSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isDecorativeMotionActive) private var isVisible
    let bossID: String
    let presentation: BattlePresentationState

    var body: some View {
        if scenePhase == .active, isVisible,
           session.dependencies.bossLyricsEnabled(),
           session.presentation === presentation,
           let configurationID = presentation.configurationID,
           session.activeBattle?.id == configurationID,
           let trackID = MusicCatalog.bossTrackIDByEnemyID[bossID],
           let phrases = MusicCatalog.lyrics(for: trackID) {
            SungBossLyrics(trackID: trackID, phrases: phrases)
                .id(trackID)
        }
    }
}

private struct SungBossLyrics: View {
    @Environment(BattleSession.self) private var session
    let trackID: String
    let phrases: [MusicLyricPhrase]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame: MusicLyricFrame?
    @State private var playbackRevision = 0
    @State private var samplerBox: BossLyricSamplerBox?

    var body: some View {
        BossLyricWordLayout {
            if let frame {
                ForEach(0 ..< frame.visibleWords, id: \.self) { index in
                    BossLyricWord(
                        text: phrases[frame.phrase].words[index].text,
                        isActive: index == frame.activeWord,
                    )
                    .id("\(frame.phrase):\(index)")
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 6)),
                        removal: .opacity,
                    ))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityIdentifier(AccessibilityID.Battle.bossLyrics)
        .task {
            guard let changes = session.dependencies.musicPlaybackChanges?() else { return }
            // Reconcile once after subscribing so a concurrent route change cannot be missed.
            playbackRevision &+= 1
            for await _ in changes {
                playbackRevision &+= 1
            }
        }
        .task(id: playbackRevision) {
            let sampler: BossLyricSamplerBox
            if let samplerBox {
                sampler = samplerBox
            } else {
                sampler = BossLyricSamplerBox(phrases: phrases)
                samplerBox = sampler
            }
            var settlingSamples = 3
            while !Task.isCancelled {
                let playback = session.dependencies.readMusicPlayback()
                let playing = playback?.trackID == trackID && playback?.isAudible == true
                let next = playing ? playback.flatMap { sampler.value.frame(at: $0.currentTime) } : nil
                if next != frame {
                    // Animate row recentering and wrapping in the same transaction as word entrances.
                    withAnimation(reduceMotion ? nil : TrinketMotion.Content.entrance) {
                        frame = next
                    }
                }
                let delay: TimeInterval
                if settlingSamples > 0 || session.dependencies.musicPlaybackChanges == nil || !playing {
                    delay = 1.0 / 60
                    settlingSamples = max(0, settlingSamples - 1)
                } else if let playback {
                    delay = sampler.value.delayUntilNextBoundary(at: playback.currentTime, duration: playback.duration)
                } else {
                    delay = 1.0 / 60
                }
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
            }
        }
    }
}

@MainActor
private final class BossLyricSamplerBox {
    var value: BossLyricSampler

    init(phrases: [MusicLyricPhrase]) {
        value = BossLyricSampler(phrases: phrases)
    }
}

/// Playback changes wake the view; media time still determines every displayed word.
struct BossLyricSampler {
    private let phrases: [MusicLyricPhrase]
    private let boundaries: [TimeInterval]
    private var interval: Range<TimeInterval>?
    private var cachedFrame: MusicLyricFrame?

    init(phrases: [MusicLyricPhrase]) {
        self.phrases = phrases
        boundaries = phrases.flatMap { $0.words.flatMap { [$0.start, $0.end] } }
            .filter(\.isFinite)
            .sorted()
    }

    mutating func frame(at time: TimeInterval) -> MusicLyricFrame? {
        guard time.isFinite else { return nil }
        if let interval, interval.contains(time) {
            return cachedFrame
        }
        var low = 0
        var high = boundaries.count
        while low < high {
            let middle = low + (high - low) / 2
            if boundaries[middle] <= time {
                low = middle + 1
            } else {
                high = middle
            }
        }
        let start = low == 0 ? -Double.infinity : boundaries[low - 1]
        let end = low == boundaries.count ? Double.infinity : boundaries[low]
        interval = start ..< end
        cachedFrame = MusicLyricFrame.at(time, in: phrases)
        return cachedFrame
    }

    func delayUntilNextBoundary(at time: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard time.isFinite else { return 1.0 / 60 }
        let next = min(interval?.upperBound ?? time, duration)
        // Periodic reconciliation covers unreported system changes and clock drift.
        return max(1.0 / 120, min(1, next - time))
    }
}

private struct BossLyricWord: View {
    let text: String
    let isActive: Bool

    private var lyricText: Text {
        switch text {
        case "[chants]": Text(L10n.ui_bosslyrics_chants)
        case "[growls]": Text(L10n.ui_bosslyrics_growls)
        case "[vocalizing]": Text(L10n.ui_bosslyrics_vocalizing)
        default: Text(verbatim: text)
        }
    }

    var body: some View {
        lyricText
            .trinketTypography(.sectionTitle)
            .fixedSize()
            .foregroundStyle(isActive ? TrinketDesign.Colors.accent : TrinketDesign.Colors.Overlay.paper.opacity(0.65))
            .trinketOnArtText()
    }
}

private struct BossLyricWordLayout: Layout {
    private let spacing: CGFloat = 5

    struct Cache {
        var sizes: [CGSize]
        var width: CGFloat?
        var rows: [Row] = []
    }

    struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = makeCache(subviews: subviews)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews _: Subviews, cache: inout Cache) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, cache: &cache)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing,
        )
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let rows = rows(width: bounds.width, cache: &cache)
        var y = bounds.minY
        for row in rows {
            var x = bounds.midX - row.width / 2
            for index in row.indices {
                let size = cache.sizes[index]
                subviews[index].place(at: CGPoint(x: x, y: y + row.height / 2), anchor: .leading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(width: CGFloat, cache: inout Cache) -> [Row] {
        if cache.width == width {
            return cache.rows
        }
        var rows: [Row] = []
        var row = Row()
        for (index, size) in cache.sizes.enumerated() {
            let gap = row.indices.isEmpty ? 0 : spacing
            if !row.indices.isEmpty, row.width + gap + size.width > width {
                rows.append(row)
                row = Row()
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty {
            rows.append(row)
        }
        cache.width = width
        cache.rows = rows
        return rows
    }
}
