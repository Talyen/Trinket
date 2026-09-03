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

    let onOpenCampaign: () -> Bool
    let onOpenExplore: () -> Bool

    @State private var modeSelectionTrigger = 0

    var body: some View {
        HubGridScaffold(
            title: "Play",
            accessibilityIdentifier: AccessibilityID.Play.modesScreen,
        ) {
            modeCard(.campaign)
            modeCard(.explore)
        }
        .trinketSensoryFeedback(
            .selection,
            trigger: modeSelectionTrigger,
            enabled: options.hapticsEnabled,
        )
    }

    private func modeCard(_ mode: Mode) -> some View {
        Button {
            let accepted: Bool = switch mode {
            case .campaign:
                onOpenCampaign()
            case .explore:
                onOpenExplore()
            }
            if accepted {
                modeSelectionTrigger &+= 1
            }
        } label: {
            HubArtworkCard(
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
