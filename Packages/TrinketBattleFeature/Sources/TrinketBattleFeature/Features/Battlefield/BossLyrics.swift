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
            while !Task.isCancelled {
                let playback = session.dependencies.readMusicPlayback()
                let next = playback?.trackID == trackID && playback?.isAudible == true
                    ? playback.flatMap { MusicLyricFrame.at($0.currentTime, in: phrases) }
                    : nil
                if next != frame {
                    // Animate row recentering and wrapping in the same transaction as word entrances.
                    withAnimation(reduceMotion ? nil : TrinketMotion.Content.entrance) {
                        frame = next
                    }
                }
                do {
                    try await Task.sleep(for: .seconds(1.0 / 60))
                } catch {
                    return
                }
            }
        }
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

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let rows = rows(subviews, width: proposal.width ?? .infinity)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing,
        )
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var y = bounds.minY
        for row in rows(subviews, width: bounds.width) {
            var x = bounds.midX - row.width / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + row.height / 2), anchor: .leading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
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
        return rows
    }
}
