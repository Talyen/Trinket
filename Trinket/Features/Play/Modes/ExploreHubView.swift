import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct ExploreHubView: View {
    @Environment(PlayerSaveStore.self) private var playerSave

    var body: some View {
        HubGridScaffold(
            title: "Explore",
            accessibilityIdentifier: AccessibilityID.Play.exploreHub,
        ) {
            NavigationLink(value: PlayLaunchDestination.spiresHub) {
                HubArtworkCard(
                    title: "The Spires",
                    subtitle: spiresProgressSubtitle,
                    symbolName: nil,
                    artID: "gameModeSpires",
                    fallbackArtID: "gameModeExplore",
                )
            }
            .accessibilityIdentifier(AccessibilityID.Play.spiresModeCard)
            .trinketArtworkCardButtonStyle()

            NavigationLink(value: PlayLaunchDestination.labyrinthMap) {
                HubArtworkCard(
                    title: "Labyrinth",
                    subtitle: "Floor \(max(1, playerSave.labyrinth.currentFloorNumber))",
                    symbolName: nil,
                    artID: "gameModeLabyrinth",
                    fallbackArtID: "gameModeExplore",
                )
            }
            .accessibilityIdentifier(AccessibilityID.Play.labyrinthModeCard)
            .trinketArtworkCardButtonStyle()
        }
    }

    private var spiresProgressSubtitle: String {
        let totalFloors = GameContent.spires.reduce(0) { partialResult, spire in
            partialResult + spire.floorCount
        }
        let clearedFloors = GameContent.spires.reduce(0) { partialResult, spire in
            partialResult + min(
                playerSave.spires.highestClearedFloor(for: spire.id.rawValue),
                spire.floorCount,
            )
        }
        return "\(clearedFloors) / \(totalFloors) Floors"
    }
}
