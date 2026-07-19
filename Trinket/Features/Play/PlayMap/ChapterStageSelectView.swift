import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Cinematic Campaign chapter overview with five stable, inline stage rows.
struct ChapterStageSelectView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

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
            DetailHeroHeader(
                eyebrow: "Chapter \(chapter.number)".uppercased(),
                title: chapter.title,
                titleAccessibilityIdentifier: AccessibilityID.Play.chapterTitle(
                    number: chapter.number
                ),
                baseHeight: baseHeight,
                overscroll: overscroll,
                horizontalPadding: TrinketDesign.Metrics.contentMargin,
                bottomPadding: TrinketDesign.Metrics.largeSpacing
            ) {
                if let art = ArtCatalog.backgroundArtByID[chapter.id]
                    ?? ArtCatalog.backgroundArtByID["chapter-1"] {
                    Image.preparedAsset(named: art.imageName)
                        .resizable()
                        .scaledToFill()
                        .decorativePreparedArtwork()
                } else {
                    chapter.theme.tint
                }
            }
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
            prepareActiveBattleRun()
            // Deep-link / restore paths skip the mode-card press prep. Finish
            // presentation warmup after the first committed frame, then await
            // atlas / dissolve so the Stage Select CTA is not the first bake.
            Task { @MainActor in
                await Task.yield()
                await BattlePresentationWarmup.prepareAndWait(
                    dynamicTypeSize: dynamicTypeSize,
                    displayScale: displayScale
                )
                appState.battle.prepareBattlePresentation(
                    heroUltimateID: appState.roster.activeHero.abilityLoadout.ultimate?.id,
                    companionUltimateID: appState.roster.activeCompanion.abilityLoadout.ultimate?.id
                )
                if let stageID = appState.journey.activeStageID {
                    let names = appState.battle.preparedAbilityArtworkNames(
                        for: .journey(stageID: stageID)
                    )
                    await PreparedArtworkCache.shared.prepareAndPin(names: names)
                }
            }
        }
        .onChange(of: appState.journey) { _, _ in
            updateMusicPreview()
            prepareActiveBattleRun()
        }
        .onChange(of: appState.roster) { _, _ in
            prepareActiveBattleRun()
        }
        .onChange(of: appState.inventory) { _, _ in
            prepareActiveBattleRun()
        }
        .onChange(of: appState.homestead) { _, _ in
            prepareActiveBattleRun()
        }
        .onDisappear {
            appState.battle.setMusicPreview(for: nil)
        }
    }

    private func prepareActiveBattleRun() {
        guard let stageID = appState.journey.activeStageID,
              let stage = GameContent.stage(id: stageID),
              stage.encounter.battleEnemyID != nil else { return }
        appState.prepareBattle(for: stage)
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
