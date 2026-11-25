import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct ChapterStageSelectView: View {
    @Environment(JourneyPlayMode.self) private var journey
    @Environment(EncounterPlayMode.self) private var encounters
    @State private var retainedPresentation: CampaignMapSnapshot?
    @Environment(PlayerSaveStore.self) private var playerSave

    let onStageTap: (Stage) -> Bool
    let onEnemyTap: (Stage) -> Void

    private var presentation: CampaignMapSnapshot {
        retainedPresentation ?? CampaignMapSnapshot(journey: journey, playerSave: playerSave)
    }

    private var hasEncounter: Bool {
        encounters.activeMysteryEncounter != nil || encounters.activeShopEncounter != nil
    }

    var body: some View {
        let presentation = presentation
        let chapter = presentation.chapter
        let isChapterLocked = !playerSave.contentAccess.allowsChapter(chapter.number)
        let lockedStageID = isChapterLocked ? presentation.rows.first(where: \.isActive)?.item.id : nil
        let chapterNumber = "\(chapter.number)"
        let eyebrow = presentation.isComplete
            ? String(localized: L10n.ui_chapterstageselectview_through_chapter_1_d6a04(chapterNumber))
            : String(localized: L10n.ui_chapterstageselectview_chapter_1_c98b7(chapterNumber))
        let title = presentation.isComplete
            ? String(localized: L10n.ui_chapterstageselectview_campaign_complete_a2b42)
            : chapter.title
        StageSelectScreen(
            eyebrow: eyebrow,
            title: title,
            subtitle: nil,
            titleAccessibilityIdentifier: AccessibilityID.Play.chapterTitle(
                number: chapter.number,
            ),
        ) {
            if let art = ArtCatalog.backgroundArtByID[chapter.id]
                ?? ArtCatalog.backgroundArtByID[EncounterArtIDs.fallbackChapterID] {
                FocalBackgroundArtwork(art: art)
            } else {
                chapter.theme.tint
            }
        } content: {
            Group {
                if presentation.isComplete {
                    campaignCompletionCards
                } else {
                    StageSelectList(
                        rows: presentation.rows,
                        isPrimaryActionDisabled: { isChapterLocked && $0.id != lockedStageID },
                        isLockedContent: { $0.id == lockedStageID },
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
        }
        .accessibilityIdentifier(AccessibilityID.Screen.play)
        .overlay(alignment: .topLeading) {
            Text(L10n.ui_chapterstageselectview_chapter_1_c98b7("\(chapter.number)"))
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

    private var campaignCompletionCards: some View {
        LazyVStack(spacing: TrinketDesign.Spacing.large) {
            ForEach(ExploreMode.campaignCompletionOrder, id: \.destination) { mode in
                mode.card()
            }
        }
        .frame(maxWidth: HubArtworkLayout.maximumWidth)
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.top, TrinketDesign.Spacing.large)
        .padding(.bottom, TrinketDesign.Spacing.extraLarge)
        .frame(maxWidth: .infinity)
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
    static func chapter(_ chapter: Chapter, save: PlayerSave, contentAccess: ContentAccessPolicy) -> Chapter {
        Chapter(
            id: chapter.id,
            number: chapter.number,
            title: chapter.title,
            theme: chapter.theme,
            stages: chapter.stages.map { stage in
                GameContent.resolveRecruitStage(
                    stage,
                    worldSeed: save.worldSeed,
                    unlockedHeroIDs: save.roster.unlockedHeroIDs,
                    unlockedCompanionIDs: save.roster.unlockedCompanionIDs,
                    access: contentAccess,
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
        chapter = CampaignStagePresentation.chapter(
            journey.playChapter,
            save: playerSave.currentSave,
            contentAccess: playerSave.contentAccess,
        )
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
