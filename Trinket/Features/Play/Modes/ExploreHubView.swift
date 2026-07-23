import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Temporary Explore landing page. The eventual world map can replace this
/// hub without changing the Play tab's top-level Campaign/Explore contract.
struct ExploreHubView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        PlayModeHubScreen(
            title: "Explore",
            accessibilityIdentifier: AccessibilityID.Play.exploreHub
        ) {
            NavigationLink(value: PlayLaunchDestination.spiresHub) {
                PlayModeArtworkCard(
                    title: "The Spires",
                    subtitle: spiresProgressSubtitle,
                    symbolName: nil,
                    artID: "spire-aureateChoir",
                    fallbackArtID: "gameModeExplore"
                )
            }
            .accessibilityIdentifier(AccessibilityID.Play.spiresModeCard)
            .trinketQuietTapButtonStyle()

            NavigationLink(value: PlayLaunchDestination.labyrinthMap) {
                PlayModeArtworkCard(
                    title: "Labyrinth",
                    subtitle: "Floor \(max(1, appState.labyrinth.currentFloorNumber))",
                    symbolName: nil,
                    artID: "gameModeLabyrinth",
                    fallbackArtID: "gameModeExplore"
                )
            }
            .accessibilityIdentifier(AccessibilityID.Play.labyrinthModeCard)
            .trinketQuietTapButtonStyle()
        }
    }

    private var spiresProgressSubtitle: String {
        let totalFloors = GameContent.spires.reduce(0) { partialResult, spire in
            partialResult + spire.floorCount
        }
        let clearedFloors = GameContent.spires.reduce(0) { partialResult, spire in
            partialResult + min(
                appState.spires.highestClearedFloor(for: spire.id.rawValue),
                spire.floorCount
            )
        }
        return "\(clearedFloors) / \(totalFloors) Floors"
    }
}
