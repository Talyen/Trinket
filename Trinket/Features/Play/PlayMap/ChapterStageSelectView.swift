import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
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

/// Invalidates prepared Stage Select / Spire battles when party, gear, or homestead effects change.
///
/// `PlayBattleLaunch` snapshots roster, inventory, and homestead into the prepared run;
/// activation reuses that snapshot when party IDs match, so these slices must participate.
@MainActor
struct StageSelectPrepareDependency: Equatable {
    let runKey: String
    let roster: PlayerRosterState
    let inventory: PlayerInventoryState
    let homestead: PlayerHomesteadState

    static func journey(playerSave: PlayerSaveStore) -> Self? {
        guard let stageID = playerSave.journey.activeStageID,
              let stage = GameContent.stage(id: stageID),
              stage.encounter.isCombat
        else { return nil }
        return Self(runKey: stageID, playerSave: playerSave)
    }

    static func spire(spireID: SpireID, floor: Int, playerSave: PlayerSaveStore) -> Self {
        Self(runKey: "\(spireID.rawValue)|\(floor)", playerSave: playerSave)
    }

    private init(runKey: String, playerSave: PlayerSaveStore) {
        self.runKey = runKey
        roster = playerSave.roster
        inventory = playerSave.inventory
        homestead = playerSave.homestead
    }
}

/// Cinematic Campaign chapter overview with five stable, inline stage rows.
struct ChapterStageSelectView: View {
    @Environment(JourneyPlayMode.self) private var journey
    @Environment(BattleSession.self) private var battle
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dismiss) private var dismiss

    let onStageTap: (Stage) -> Void
    let onEnemyTap: (Stage) -> Void

    private var chapter: Chapter {
        journey.playChapter
    }

    private var stageRows: [StageSelectRowPresentation<Stage>] {
        StageSelectRowPresentation.stageRows(
            for: chapter,
            progress: playerSave.journey
        )
    }

    private var isCampaignComplete: Bool {
        playerSave.journey.activeStageID == nil && stageRows.isEmpty
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
            Group {
                if isCampaignComplete {
                    campaignCompletionState
                } else {
                    StageSelectList(
                        rows: stageRows,
                        isPrimaryActionDisabled: { _ in false },
                        onArtworkTap: onEnemyTap,
                        onPrimaryAction: handlePrimaryAction,
                        artwork: { stage in
                            EncounterArtwork(
                                stage: stage,
                                resolvedMysteryEvent: resolvedMysteryEvent(for: stage)
                            )
                        },
                        partyPickerSheet: { _ in
                            StageBattlePartyPickerSheet()
                        }
                    )
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
        .task(id: StageSelectPrepareDependency.journey(playerSave: playerSave)) {
            prepareActiveBattleRun()
        }
    }

    private var campaignCompletionState: some View {
        VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
            ContentUnavailableView(
                "Campaign Complete",
                systemImage: "checkmark.seal.fill",
                description: Text("Every chapter stage is complete.")
            )

            Button("Back to Play") {
                dismiss()
            }
            .frame(maxWidth: .infinity)
            .trinketPrimaryActionButton(
                tint: chapter.theme.tint,
                accessibilityIdentifier: AccessibilityID.Play.campaignCompletionBack
            )
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .padding(.vertical, TrinketDesign.Metrics.largeSpacing)
    }

    private func prepareActiveBattleRun() {
        guard let stageID = playerSave.journey.activeStageID,
              let stage = GameContent.stage(id: stageID),
              stage.encounter.isCombat else { return }
        journey.prepareBattle(for: stage)
    }

    private func handlePrimaryAction(_ stage: Stage) {
        guard playerSave.journey.isActive(stage) else { return }
        onStageTap(stage)
    }

    private func resolvedMysteryEvent(for stage: Stage) -> MysteryEvent? {
        guard case .mysteryEvent = stage.encounter else { return nil }
        let pickContext = MysteryEventPickContext.journey(
            chapterNumber: stage.chapterNumber,
            inventory: playerSave.inventory,
            corruptionAltarCooldownRemaining: playerSave.currentSave.corruptionAltarCooldownRemaining
        )
        return GameContent.resolveJourneyMysteryEvent(
            stage: stage,
            pinnedEventID: playerSave.journey.pinnedMysteryEventIDs[stage.id],
            context: pickContext
        )
    }
}
