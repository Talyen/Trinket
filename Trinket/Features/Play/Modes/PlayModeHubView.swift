import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct PlayModeHubView: View {
    @Environment(JourneyPlayMode.self) private var journey
    @Environment(PlayerSaveStore.self) private var playerSave

    var body: some View {
        HubGridScaffold(
            title: "Play",
            accessibilityIdentifier: AccessibilityID.Play.modesScreen,
        ) {
            HubArtworkNavigationLink(
                destination: PlayLaunchDestination.campaign,
                title: "Campaign",
                subtitle: campaignSubtitle,
                icon: .system("map.fill"),
                artID: "gameModeCampaign",
                fallbackArtID: "chapter-1",
                accessibilityIdentifier: AccessibilityID.Play.campaignModeCard,
            )

            HubArtworkNavigationLink(
                destination: PlayLaunchDestination.explore,
                title: "Explore",
                subtitle: nil,
                artID: "gameModeExplore",
                fallbackArtID: "homestead",
                accessibilityIdentifier: AccessibilityID.Play.exploreModeCard,
            )
        }
    }

    private var campaignSubtitle: String {
        if let stageID = playerSave.journey.activeStageID,
           let stage = GameContent.stage(id: stageID) {
            return stage.mapLabel
        }
        return "Chapter \(journey.playChapter.number) · Complete"
    }
}
