import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

/// Cinematic header and scrolling body shared by linear Stage Select surfaces.
struct StageSelectScreen<HeroArt: View, Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String?
    let titleAccessibilityIdentifier: String?
    @ViewBuilder let heroArt: () -> HeroArt
    @ViewBuilder let content: () -> Content

    var body: some View {
        DetailHeroScrollShell(
            title: title,
            heroHeightPolicy: .cinematicLandscape
        ) { baseHeight, overscroll in
            DetailHeroHeader(
                eyebrow: eyebrow,
                title: title,
                titleAccessibilityIdentifier: titleAccessibilityIdentifier,
                baseHeight: baseHeight,
                overscroll: overscroll,
                horizontalPadding: TrinketDesign.Metrics.contentMargin,
                bottomPadding: TrinketDesign.Metrics.largeSpacing
            ) {
                heroArt()
            } footer: {
                if let subtitle {
                    Text(subtitle)
                        .trinketTypography(.secondaryBody)
                        .trinketOnArtText(.eyebrow)
                }
            }
        } bodyContent: {
            content()
        }
    }
}

/// Cinematic Campaign chapter overview with five stable, inline stage rows.
struct ChapterStageSelectView: View {
    @Environment(PlaySession.self) private var play
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    let onStageTap: (Stage) -> Void
    let onEnemyTap: (Stage) -> Void

    private var chapter: Chapter {
        play.journey.playChapter
    }

    var body: some View {
        StageSelectScreen(
            eyebrow: "Chapter \(chapter.number)".uppercased(),
            title: chapter.title,
            subtitle: nil,
            titleAccessibilityIdentifier: AccessibilityID.Play.chapterTitle(
                number: chapter.number
            )
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
        } content: {
            StageSelectList(
                rows: stageRows,
                isPrimaryActionDisabled: { _ in false },
                onArtworkTap: onEnemyTap,
                onPrimaryAction: handlePrimaryAction,
                artwork: { stage in
                    EncounterArtwork(stage: stage)
                },
                partyPickerSheet: { _ in
                    StageBattlePartyPickerSheet()
                }
            )
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
                play.battle.prepareBattlePresentation(
                    heroUltimateID: playerSave.roster.activeHero.abilityLoadout.ultimate?.id,
                    companionUltimateID: playerSave.roster.activeCompanion.abilityLoadout.ultimate?.id
                )
                if let stageID = playerSave.journey.activeStageID {
                    let names = play.battle.preparedAbilityArtworkNames(
                        for: .journey(stageID: stageID)
                    )
                    await PreparedArtworkCache.shared.prepareAndPin(names: names)
                }
            }
        }
        .onChange(of: playerSave.journey) { _, _ in
            prepareActiveBattleRun()
        }
        .onChange(of: playerSave.roster) { _, _ in
            prepareActiveBattleRun()
        }
        .onChange(of: playerSave.inventory) { _, _ in
            prepareActiveBattleRun()
        }
        .onChange(of: playerSave.homestead) { _, _ in
            prepareActiveBattleRun()
        }
    }

    private func prepareActiveBattleRun() {
        guard let stageID = playerSave.journey.activeStageID,
              let stage = GameContent.stage(id: stageID),
              stage.encounter.isCombat else { return }
        play.journey.prepareBattle(for: stage)
    }

    private var stageRows: [StageSelectRowPresentation<Stage>] {
        ChapterStageRowPresentation.rows(
            for: chapter,
            progress: playerSave.journey
        )
        .filter { !$0.isCompleted }
        .map { row in
            // Keep the map artwork tied to the authored recruit event. The
            // configured recruit can be resolved to a fallback only when the
            // player takes the stage action; resolving it here makes the card
            // artwork change as roster state settles during navigation.
            let stage = row.stage
            return StageSelectRowPresentation(
                item: stage,
                isActive: row.isActionable,
                activeEyebrow: stage.mapLabel,
                mapLabel: stage.mapLabel,
                title: stage.encounterSubjectName,
                activeDetailLines: [],
                encounterTypeTitle: stage.encounterTypeTitle,
                symbolName: stage.encounter.symbolName,
                tint: stage.encounter.mapTint,
                primaryActionTitle: stage.encounter.primaryActionTitle,
                showsPartyPicker: stage.encounter.isCombat,
                isArtworkInteractive: stage.encounter.isCombat,
                rowAccessibilityID: AccessibilityID.Play.stageRow(
                    chapter: stage.chapterNumber,
                    stage: stage.stageNumber
                ),
                artworkAccessibilityID: artworkAccessibilityIdentifier(for: stage),
                actionAccessibilityID: StageMapID.stageAction(for: stage),
                activeDetailAccessibilityID: AccessibilityID.Play.activeStageDetail,
                partyControlAccessibilityID: AccessibilityID.Play.stagePartyControl
            )
        }
    }

    private func handlePrimaryAction(_ stage: Stage) {
        guard playerSave.journey.isActive(stage) else { return }
        onStageTap(stage)
    }

    private func artworkAccessibilityIdentifier(for stage: Stage) -> String {
        if stage.encounter.isCombat {
            return "\(stage.mapLabel) Enemy Art"
        }
        if stage.encounter.eventID != nil {
            return "\(stage.mapLabel) Mystery Art"
        }
        return "\(stage.mapLabel) Encounter Art"
    }
}
