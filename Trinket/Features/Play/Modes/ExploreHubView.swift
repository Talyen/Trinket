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
            HubArtworkNavigationLink(
                destination: PlayLaunchDestination.spiresHub,
                title: "The Spires",
                subtitle: spiresProgressSubtitle,
                artID: "gameModeSpires",
                fallbackArtID: "gameModeExplore",
                accessibilityIdentifier: AccessibilityID.Play.spiresModeCard,
            )

            HubArtworkNavigationLink(
                destination: PlayLaunchDestination.labyrinthMap,
                title: "Labyrinth",
                subtitle: "Floor \(max(1, playerSave.labyrinth.currentFloorNumber))",
                artID: "gameModeLabyrinth",
                fallbackArtID: "gameModeExplore",
                accessibilityIdentifier: AccessibilityID.Play.labyrinthModeCard,
            )

            HubArtworkNavigationLink(
                destination: PlayLaunchDestination.contracts,
                title: "Contracts",
                subtitle: nil,
                artID: "gameModeExplore",
                accessibilityIdentifier: AccessibilityID.Play.contractsModeCard,
            )
        }
    }

    private var spiresProgressSubtitle: String {
        let totalFloors = GameContent.spires.reduce(0) { partialResult, spire in
            partialResult + spire.floorCount
        }
        let clearedFloors = GameContent.spires.reduce(0) { partialResult, spire in
            partialResult + SpiresProgress.clampedClearedFloors(
                highestCleared: playerSave.spires.highestClearedFloor(for: spire.id.rawValue),
                floorCount: spire.floorCount,
            )
        }
        return SpiresProgress.floorsText(cleared: clearedFloors, total: totalFloors)
    }
}
