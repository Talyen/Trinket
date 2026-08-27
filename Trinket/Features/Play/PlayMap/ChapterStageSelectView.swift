import SwiftUI
import TrinketAppState
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

/// Empty completion panel shared by campaign chapter select and spire climb.
struct StageSelectCompletionPanel: View {
    let title: String
    let description: String
    let buttonTitle: String
    let tint: Color
    let accessibilityIdentifier: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
            ContentUnavailableView(
                title,
                systemImage: "checkmark.seal.fill",
                description: Text(description)
            )

            Button(buttonTitle, action: onBack)
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton(
                    tint: tint,
                    accessibilityIdentifier: accessibilityIdentifier
                )
                .trinketCenteredPrimaryAction()
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .padding(.vertical, TrinketDesign.Metrics.largeSpacing)
    }
}

/// Invalidates prepared Stage Select / Spire battles when party, gear, homestead,
/// world seed, or claimed-reward state change.
///
/// `PlayBattleLaunch` snapshots those inputs into the prepared run;
/// activation reuses that snapshot when party IDs match, so they must participate.
@MainActor
struct StageSelectPrepareDependency: Equatable {
    let runKey: String
    let roster: PlayerRosterState
    let inventory: PlayerInventoryState
    let homestead: PlayerHomesteadState
    let worldSeed: UInt64
    let stageRewardsAlreadyClaimed: Bool

    static func journey(playerSave: PlayerSaveStore) -> Self? {
        guard let stageID = playerSave.journey.activeStageID,
              let stage = GameContent.stage(id: stageID),
              stage.encounter.isCombat
        else { return nil }
        return Self(
            runKey: stageID,
            playerSave: playerSave,
            stageRewardsAlreadyClaimed: playerSave.journey.hasClaimedRewards(for: stage)
        )
    }

    static func spire(spireID: SpireID, floor: Int, playerSave: PlayerSaveStore) -> Self {
        Self(runKey: "\(spireID.rawValue)|\(floor)", playerSave: playerSave)
    }

    static func labyrinth(playerSave: PlayerSaveStore) -> Self {
        let labyrinth = playerSave.labyrinth
        let runKey = labyrinth.reachableNodeIDs().compactMap { nodeID -> String? in
            guard let node = labyrinth.node(id: nodeID), node.type.isCombat else { return nil }
            return "\(nodeID)|\(node.modifierIDs.map(\.rawValue).joined(separator: ","))"
        }
        .sorted()
        .joined(separator: ";")
        return Self(runKey: runKey, playerSave: playerSave)
    }

    private init(
        runKey: String,
        playerSave: PlayerSaveStore,
        stageRewardsAlreadyClaimed: Bool = false
    ) {
        self.runKey = runKey
        roster = playerSave.roster
        inventory = playerSave.inventory
        homestead = playerSave.homestead
        worldSeed = playerSave.worldSeed
        self.stageRewardsAlreadyClaimed = stageRewardsAlreadyClaimed
    }
}

/// Cinematic Campaign chapter overview with five stable, inline stage rows.
struct ChapterStageSelectView: View {
    @Environment(JourneyPlayMode.self) private var journey
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
            progress: playerSave.journey,
            worldSeed: playerSave.worldSeed
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
                Image.preparedAsset(art, displaySize: .full)
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
                        artwork: { stage, isActive in
                            EncounterArtwork(
                                stage: stage,
                                resolvedMysteryEvent: journey.previewMysteryEvent(for: stage),
                                worldSeed: playerSave.worldSeed,
                                prefersThumbnail: !isActive
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
        StageSelectCompletionPanel(
            title: "Campaign Complete",
            description: "Every chapter stage is complete.",
            buttonTitle: "Back to Play",
            tint: chapter.theme.tint,
            accessibilityIdentifier: AccessibilityID.Play.campaignCompletionBack,
            onBack: { dismiss() }
        )
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
}
