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
        appState.journey.pendingNextChapter()
    }

    var body: some View {
        DetailHeroScrollShell(
            title: chapter.title,
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
                        .padding(.top, TrinketDesign.Metrics.smallSpacing)
                }
            }
            .padding(.bottom, TrinketDesign.Metrics.compactTabBarContentClearance)
        }
        .accessibilityIdentifier(AccessibilityID.Screen.play)
        .overlay(alignment: .topLeading) {
            Text("Chapter \(chapter.number)")
                .accessibilityIdentifier(
                    AccessibilityID.Play.chapterHeader(number: chapter.number)
                )
                .frame(width: 0, height: 0)
                .opacity(0)
        }
        .onAppear {
            updateMusicPreview()
            appState.battle.prepareBattlePresentation(
                heroUltimateID: appState.roster.activeHero.abilityLoadout.ultimate?.id,
                companionUltimateID: appState.roster.activeCompanion.abilityLoadout.ultimate?.id
            )
        }
        .onChange(of: appState.journey) { _, _ in
            updateMusicPreview()
        }
        .onDisappear {
            appState.battle.setMusicPreview(for: nil)
        }
    }

    private var stageRows: [ChapterStageRowPresentation] {
        ChapterStageRowPresentation.rows(
            for: chapter,
            progress: appState.journey
        ).filter { !$0.isCompleted }
    }

    private func handlePrimaryAction(_ stage: Stage) {
        guard appState.journey.isActive(stage) else { return }
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
    }

    private func updateMusicPreview() {
        let activeStage = appState.journey.activeStageID.flatMap(GameContent.stage(id:))
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
            alignment: .bottomLeading,
            artworkBlend: .bottom(into: .canvas)
        ) {
            if let art {
                Image.preparedAsset(named: art.imageName)
                    .resizable()
                    .scaledToFill()
                    .decorativePreparedArtwork()

            } else {
                chapter.theme.tint
            }
        } overlay: {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.denseSpacing) {
                Text("Chapter \(chapter.number)".uppercased())
                    .trinketTypography(.eyebrow)
                    .trinketOnArtText(.eyebrow)

                Text(chapter.title)
                    .trinketTypography(.screenDisplay)
                    .trinketOnArtText(.title)
                    .accessibilityIdentifier(
                        AccessibilityID.Play.chapterTitle(number: chapter.number)
                    )
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.bottom, TrinketDesign.Metrics.largeSpacing)
        }
    }
}
