import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

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
            heroHeightPolicy: .cinematicLandscape,
        ) { baseHeight in
            DetailHeroHeader(
                eyebrow: eyebrow,
                title: title,
                titleAccessibilityIdentifier: titleAccessibilityIdentifier,
                baseHeight: baseHeight,
                horizontalPadding: TrinketDesign.Layout.contentMargin,
                bottomPadding: TrinketDesign.Spacing.large,
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

struct StageSelectCompletionPanel: View {
    let title: String
    let description: String
    let buttonTitle: String
    let tint: Color
    let accessibilityIdentifier: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: TrinketDesign.Spacing.large) {
            ContentUnavailableView(
                title,
                systemImage: "checkmark.seal.fill",
                description: Text(description),
            )

            Button(buttonTitle, action: onBack)
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton(
                    tint: tint,
                    accessibilityIdentifier: accessibilityIdentifier,
                )
                .trinketCenteredPrimaryAction()
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.large)
    }
}

struct ChapterStageSelectView: View {
    @Environment(JourneyPlayMode.self) private var journey
    @Environment(EncounterPlayMode.self) private var encounters
    @State private var retainedPresentation: CampaignMapSnapshot?
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dismiss) private var dismiss

    let onStageTap: (Stage) -> Bool
    let onEnemyTap: (Stage) -> Void

    private var chapter: Chapter {
        presentation.chapter
    }

    private var presentation: CampaignMapSnapshot {
        retainedPresentation ?? CampaignMapSnapshot(journey: journey, playerSave: playerSave)
    }

    private var hasEncounter: Bool {
        encounters.activeMysteryEncounter != nil || encounters.activeShopEncounter != nil
    }

    var body: some View {
        let presentation = presentation
        let chapter = presentation.chapter
        StageSelectScreen(
            eyebrow: "Chapter \(chapter.number)".uppercased(),
            title: chapter.title,
            subtitle: nil,
            titleAccessibilityIdentifier: AccessibilityID.Play.chapterTitle(
                number: chapter.number,
            ),
        ) {
            if let art = ArtCatalog.backgroundArtByID[chapter.id]
                ?? ArtCatalog.backgroundArtByID["chapter-1"] {
                FocalBackgroundArtwork(art: art)
            } else {
                chapter.theme.tint
            }
        } content: {
            Group {
                if presentation.isComplete {
                    campaignCompletionState
                } else {
                    if !playerSave.contentAccess.allowsChapter(chapter.number) {
                        FullGameBoundaryView(title: chapter.title, origin: .campaign(chapter: chapter.number))
                    }
                    StageSelectList(
                        rows: presentation.rows,
                        isPrimaryActionDisabled: { _ in !playerSave.contentAccess.allowsChapter(chapter.number) },
                        onArtworkTap: onEnemyTap,
                        onPrimaryAction: handlePrimaryAction,
                        artwork: { stage, isActive in
                            EncounterArtwork(
                                stage: stage,
                                resolvedMysteryEvent: presentation.events[stage.id],
                                worldSeed: playerSave.worldSeed,
                                prefersThumbnail: !isActive,
                            )
                        },
                        partyPickerSheet: { _ in
                            StageBattlePartyPickerSheet()
                        },
                    )
                }
            }
            .padding(.bottom, TrinketDesign.Layout.compactTabBarContentClearance)
        }
        .accessibilityIdentifier(AccessibilityID.Screen.play)
        .overlay(alignment: .topLeading) {
            Text("Chapter \(chapter.number)")
                .accessibilityIdentifier(
                    AccessibilityID.Play.chapterHeader(number: chapter.number),
                )
                .frame(width: 0, height: 0)
                .opacity(0)
        }
        .onChange(of: hasEncounter) { _, isActive in
            guard !isActive else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                retainedPresentation = nil
            }
        }
        .task(id: StageSelectPrepareDependency.journey(playerSave: playerSave)) {
            prepareActiveBattleRun()
        }
    }

    private var campaignCompletionState: some View {
        StageSelectCompletionPanel(
            title: "Campaign Complete",
            description: "Every chapter stage is complete.",
            buttonTitle: "Back to Play",
            tint: chapter.theme.tint,
            accessibilityIdentifier: AccessibilityID.Play.campaignCompletionBack,
            onBack: { dismiss() },
        )
    }

    private func prepareActiveBattleRun() {
        guard let stageID = playerSave.journey.activeStageID,
              let stage = GameContent.stage(id: stageID),
              stage.encounter.isCombat else { return }
        journey.prepareBattle(for: stage)
    }

    private func handlePrimaryAction(_ stage: Stage) -> Bool {
        guard !hasEncounter, playerSave.journey.isActive(stage) else { return false }
        retainedPresentation = presentation
        let accepted = onStageTap(stage)
        if !hasEncounter {
            retainedPresentation = nil
        }
        return accepted
    }
}

@MainActor
enum CampaignStagePresentation {
    static func chapter(_ chapter: Chapter, playerSave: PlayerSaveStore) -> Chapter {
        Chapter(
            id: chapter.id,
            number: chapter.number,
            title: chapter.title,
            theme: chapter.theme,
            stages: chapter.stages.map { stage in
                GameContent.resolveRecruitStage(
                    stage,
                    worldSeed: playerSave.worldSeed,
                    unlockedHeroIDs: playerSave.roster.unlockedHeroIDs,
                    unlockedCompanionIDs: playerSave.roster.unlockedCompanionIDs,
                    access: playerSave.contentAccess,
                )
            },
        )
    }
}

@MainActor
private struct CampaignMapSnapshot {
    let chapter: Chapter
    let rows: [StageSelectRowPresentation<Stage>]
    let events: [String: MysteryEvent]
    let isComplete: Bool

    init(journey: JourneyPlayMode, playerSave: PlayerSaveStore) {
        chapter = CampaignStagePresentation.chapter(journey.playChapter, playerSave: playerSave)
        rows = StageSelectRowPresentation.stageRows(
            for: chapter,
            progress: playerSave.journey,
            worldSeed: playerSave.worldSeed,
        )
        events = Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            journey.previewMysteryEvent(for: row.item).map { (row.item.id, $0) }
        })
        isComplete = playerSave.journey.activeStageID == nil && rows.isEmpty
    }
}
