import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Cinematic Campaign chapter overview with five stable, inline stage rows.
struct ChapterStageSelectView: View {
    @Environment(AppState.self) private var appState

    let onStageTap: (Stage) -> Void
    let onEnemyTap: (Stage) -> Void

    private var chapter: Chapter {
        appState.playChapter
    }

    private var pendingNextChapter: Chapter? {
        appState.journey.current.pendingNextChapter()
    }

    var body: some View {
        DetailHeroScrollShell(
            title: chapter.title,
            backgroundMode: .playJourney,
            heroHeightPolicy: .cinematicLandscape
        ) { baseHeight, overscroll in
            ChapterJourneyHero(
                chapter: chapter,
                baseHeight: baseHeight,
                overscroll: overscroll
            )
        } bodyContent: {
            VStack(spacing: 0) {
                ChapterStageList(
                    rows: stageRows,
                    onEnemyTap: onEnemyTap,
                    onPrimaryAction: handlePrimaryAction
                )

                if let pendingNextChapter {
                    chapterAdvanceButton(to: pendingNextChapter)
                        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                        .padding(.top, 8)
                }
            }
            .padding(.bottom, 92)
        }
        .accessibilityIdentifier(AccessibilityID.Screen.play)
        .overlay(alignment: .topLeading) {
            Text("Chapter \(chapter.number)")
                .accessibilityIdentifier(
                    AccessibilityID.Play.chapterHeader(number: chapter.number)
                )
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(false)
        }
        .onAppear {
            updateMusicPreview()
        }
        .onChange(of: appState.journey.current) { _, _ in
            updateMusicPreview()
        }
        .onDisappear {
            appState.battle.setMusicPreview(for: nil)
        }
    }

    private var stageRows: [ChapterStageRowPresentation] {
        ChapterStageRowPresentation.rows(
            for: chapter,
            progress: appState.journey.current
        )
    }

    private func handlePrimaryAction(_ stage: Stage) {
        guard appState.journey.current.isActive(stage) else { return }
        onStageTap(stage)
    }

    private func chapterAdvanceButton(to nextChapter: Chapter) -> some View {
        Button {
            _ = appState.advanceToNextChapter()
        } label: {
            Label(
                "Continue to Chapter \(nextChapter.number)",
                systemImage: "arrow.right.circle.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .trinketPrimaryActionButton(controlSize: .large)
        .accessibilityIdentifier(AccessibilityID.Play.chapterAdvance)
        .accessibilityLabel(
            "Continue to Chapter \(nextChapter.number), \(nextChapter.title)"
        )
        .accessibilityHint("Begin the next chapter")
    }

    private func updateMusicPreview() {
        let activeStage = appState.journey.current.activeStageID.flatMap(GameContent.stage(id:))
        appState.battle.setMusicPreview(for: activeStage)
    }
}

private struct ChapterJourneyHero: View {
    let chapter: Chapter
    let baseHeight: CGFloat
    let overscroll: CGFloat

    private var art: BackgroundArtReference? {
        ArtCatalog.backgroundArtByID[chapter.id]
            ?? ArtCatalog.backgroundArtByID["chapter-1"]
    }

    var body: some View {
        OverscrollHeroContainer(
            baseHeight: baseHeight,
            overscroll: overscroll,
            alignment: .bottomLeading
        ) {
            if let art {
                Image(art.imageName)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(art.accessibilityLabel)
            } else {
                chapter.theme.tint
                    .accessibilityLabel("\(chapter.title) chapter artwork")
            }
        } overlay: {
            ZStack(alignment: .bottomLeading) {
                TrinketHeroScrim.gradient(
                    for: .chapter,
                    startPoint: .init(x: 0.5, y: 0.35),
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Chapter \(chapter.number)".uppercased())
                        .trinketTypography(.eyebrow)
                        .trinketOnArtText(.eyebrow)

                    Text(chapter.title)
                        .trinketTypography(.screenDisplay)
                        .trinketOnArtText(.title)
                        .accessibilityIdentifier(
                            AccessibilityID.Play.chapterTitle(number: chapter.number)
                        )
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.bottom, 16)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
