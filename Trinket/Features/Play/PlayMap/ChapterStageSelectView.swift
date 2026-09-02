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
            stageRewardsAlreadyClaimed: playerSave.journey.hasClaimedRewards(for: stage),
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
        stageRewardsAlreadyClaimed: Bool = false,
    ) {
        self.runKey = runKey
        roster = playerSave.roster
        inventory = playerSave.inventory
        homestead = playerSave.homestead
        worldSeed = playerSave.worldSeed
        self.stageRewardsAlreadyClaimed = stageRewardsAlreadyClaimed
    }
}

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
            worldSeed: playerSave.worldSeed,
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
                number: chapter.number,
            ),
        ) {
            if let art = ArtCatalog.backgroundArtByID[chapter.id]
                ?? ArtCatalog.backgroundArtByID["chapter-1"] {
                ChapterHeroFocalArtwork(art: art)
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

    private func handlePrimaryAction(_ stage: Stage) {
        guard playerSave.journey.isActive(stage) else { return }
        onStageTap(stage)
    }
}

private struct ChapterHeroFocalArtwork: View {
    let art: BackgroundArtReference

    private let sourceAspectRatio: CGFloat = 4.0 / 3.0

    var body: some View {
        GeometryReader { geometry in
            let container = geometry.size
            let scale = max(container.width / sourceAspectRatio, container.height)
            let renderedWidth = sourceAspectRatio * scale
            let renderedHeight = scale
            let overflowX = max(renderedWidth - container.width, 0)
            let overflowY = max(renderedHeight - container.height, 0)
            let offsetX = (0.5 - art.focalPoint.x) * overflowX
            let offsetY = (0.5 - art.focalPoint.y) * overflowY

            Image.preparedAsset(art, displaySize: .full)
                .resizable()
                .interpolation(.medium)
                .scaledToFill()
                .frame(width: container.width, height: container.height)
                .decorativePreparedArtwork()
                .offset(x: offsetX, y: offsetY)
        }
        .clipped()
        .allowsHitTesting(false)
    }
}
