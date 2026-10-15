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
            title: String(localized: L10n.ui_playmodehubview_play_436e6),
            accessibilityIdentifier: AccessibilityID.Play.modesScreen,
        ) {
            HubArtworkNavigationLink(
                destination: PlayLaunchDestination.campaign,
                title: String(localized: L10n.ui_playmodehubview_campaign_26828),
                subtitle: campaignSubtitle,
                icon: .system("map.fill"),
                artID: EncounterArtIDs.campaignPlayModeID,
                fallbackArtID: EncounterArtIDs.fallbackChapterID,
                accessibilityIdentifier: AccessibilityID.Play.campaignModeCard,
            )

            HubArtworkNavigationLink(
                destination: PlayLaunchDestination.explore,
                title: String(localized: L10n.ui_playmodehubview_explore_3b739),
                subtitle: nil,
                artID: EncounterArtIDs.explorePlayModeID,
                fallbackArtID: EncounterArtIDs.homesteadHeroID,
                accessibilityIdentifier: AccessibilityID.Play.exploreModeCard,
            )
        }
    }

    private var campaignSubtitle: String {
        if let stageID = playerSave.journey.activeStageID,
           let stage = GameContent.stage(id: stageID) {
            return stage.mapLabel
        }
        return String(localized: L10n.ui_playmodehubview_chapter_1_complete_88d91("\(journey.playChapter.number)"))
    }
}
