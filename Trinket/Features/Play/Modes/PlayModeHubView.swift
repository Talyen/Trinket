import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct PlayModeHubView: View {
    @Environment(JourneyPlayMode.self) private var journey
    @Environment(OptionsStore.self) private var options
    @Environment(PlayerSaveStore.self) private var playerSave

    let onOpenCampaign: () -> Void
    let onOpenExplore: () -> Void

    @State private var committedSelection: Mode?

    var body: some View {
        PlayModeHubScreen(
            title: "Play",
            accessibilityIdentifier: AccessibilityID.Play.modesScreen,
        ) {
            modeCard(.campaign)
            modeCard(.explore)
        }
        .trinketSensoryFeedback(
            .selection,
            trigger: committedSelection,
            enabled: options.hapticsEnabled,
        )
    }

    private func modeCard(_ mode: Mode) -> some View {
        Button {
            committedSelection = mode
            switch mode {
            case .campaign:
                onOpenCampaign()
            case .explore:
                onOpenExplore()
            }
        } label: {
            PlayModeArtworkCard(
                title: mode.title,
                subtitle: subtitle(for: mode),
                symbolName: mode.symbolName,
                artID: mode.artID,
                fallbackArtID: mode.fallbackArtID,
            )
        }
        .trinketArtworkCardButtonStyle()
        .accessibilityIdentifier(mode.accessibilityIdentifier)
    }

    private func subtitle(for mode: Mode) -> String? {
        switch mode {
        case .campaign:
            if let stageID = playerSave.journey.activeStageID,
               let stage = GameContent.stage(id: stageID) {
                return stage.mapLabel
            }
            return "Chapter \(journey.playChapter.number) · Complete"
        case .explore:
            return nil
        }
    }

    fileprivate enum Mode: CaseIterable, Hashable {
        case campaign
        case explore

        var title: String {
            switch self {
            case .campaign: "Campaign"
            case .explore: "Explore"
            }
        }

        var symbolName: String? {
            switch self {
            case .campaign: "map.fill"
            case .explore: nil
            }
        }

        var accessibilityIdentifier: String {
            switch self {
            case .campaign: AccessibilityID.Play.campaignModeCard
            case .explore: AccessibilityID.Play.exploreModeCard
            }
        }

        var artID: String {
            switch self {
            case .campaign: "gameModeCampaign"
            case .explore: "gameModeExplore"
            }
        }

        var fallbackArtID: String {
            switch self {
            case .campaign: "chapter-1"
            case .explore: "homestead"
            }
        }
    }
}

struct PlayModeArtworkCard: View {
    let title: String
    let subtitle: String?
    let symbolName: String?
    let artID: String
    let fallbackArtID: String
    var isLocked = false

    private var art: BackgroundArtReference? {
        ArtCatalog.backgroundArtByID[artID]
            ?? ArtCatalog.backgroundArtByID[fallbackArtID]
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let art {
                    HomesteadFocalArtwork(art: art)

                } else {
                    TrinketDesign.Colors.surface
                }
            }
            .trinketLockedCardEffect(isLocked: isLocked)

            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                if let subtitle {
                    HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Spacing.small) {
                        if let symbolName {
                            Image(systemName: symbolName)
                                .trinketTypography(.eyebrow)
                        }

                        Text(subtitle)
                            .trinketTypography(.secondaryBody)
                            .lineLimit(isLocked ? 3 : 2)
                    }
                    .trinketOnArtText(.eyebrow)
                }

                Text(title)
                    .trinketTypography(.screenDisplay)
                    .trinketOnArtText(.title)
                    .lineLimit(1)
            }
            .padding(TrinketDesign.Spacing.large)
        }
        .aspectRatio(1.35, contentMode: .fit)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape.strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1)
        }
        .shadow(
            color: TrinketDesign.Colors.Overlay.ink.opacity(0.42),
            radius: 12,
            y: 6,
        )
    }
}
