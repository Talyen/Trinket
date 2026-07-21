import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// The Play tab's root: two broad choices with a clear visual promise.
///
/// Campaign remains the existing linear Chapter/Stage journey. Explore is the
/// home for the currently available open-ended sub-modes while the future
/// world map is being designed.
struct PlayModeHubView: View {
    @Environment(AppState.self) private var appState

    let onOpenCampaign: () -> Void
    let onOpenExplore: () -> Void

    @State private var committedSelection: Mode?

    var body: some View {
        PlayModeHubScreen(
            title: "Play",
            accessibilityIdentifier: AccessibilityID.Play.modesScreen
        ) {
            modeCard(.campaign)
            modeCard(.explore)
        }
        .trinketSensoryFeedback(
            .selection,
            trigger: committedSelection,
            enabled: appState.options.hapticsEnabled
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
                fallbackArtID: mode.fallbackArtID
            )
        }
        .trinketQuietTapButtonStyle()
        .accessibilityIdentifier(mode.accessibilityIdentifier)
    }

    private func subtitle(for mode: Mode) -> String? {
        switch mode {
        case .campaign:
            if let stageID = appState.journey.activeStageID,
               let stage = GameContent.stage(id: stageID) {
                return stage.mapLabel
            }
            return "Chapter \(appState.playChapter.number) · Complete"
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
            .trinketLockedCardEffect(isLocked: isLocked, text: isLocked ? "Locked" : nil)

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                if let subtitle {
                    HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Metrics.smallSpacing) {
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
            .padding(TrinketDesign.Metrics.largeSpacing)
        }
        .aspectRatio(1.35, contentMode: .fit)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape.strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1)
        }
        .shadow(
            color: TrinketDesign.Colors.Overlay.ink.opacity(0.42),
            radius: 12,
            y: 6
        )
    }
}
